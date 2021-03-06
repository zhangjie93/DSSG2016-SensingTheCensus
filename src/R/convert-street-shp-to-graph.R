library(readr)
library(dplyr)
library(maptools)
library(sp)
library(rgdal)
library(leaflet)
library(rgeos)
library(shp2graph)
library(magrittr)
library(RColorBrewer)
library(webshot)
library(htmlwidgets)
# install_github("wch/webshot")

source("src/R/utils.R")

#' Read Street network shapefile
streets = readOGR("data/OSM/milroads/milroads.shp",layer = "milroads" ) %>%
  spTransform(CRS("+proj=utm +zone=32 +datum=WGS84 +units=m")) 

# streets = readOGR("data/OSM/mexico_city_streets/calle50_l.shp", "calles")

# streets = readShapeSpatial("data/OSM/mexico_city_streets/calle50_l.shp")
# prj4string = CRS("+proj=utm +zone=14 +ellps=GRS80 +datum=NAD83 +units=m +no_defs ")

#' Remove unwanted paths
streets %<>%subset(!type %in% c("footway", "pedestrian", "cycleway", "elevator", "rest_area", "steps"))


# Plot street shapefile
# streets%>% spTransform(CRS("+init=epsg:4326")) %>% leaflet() %>%
  # addProviderTiles("CartoDB.Positron") %>%
  # addPolylines(weight = .4, color="black")

#' Create graph object from shapefile
street_graph_list = readshpnw(streets, ELComputed=TRUE, longlat=FALSE) 
street_graph = nel2igraph(street_graph_list[[2]],street_graph_list[[3]],
                          weight=street_graph_list[[4]])
                          # eadf = street_graph_list[[5]])

#' Remove self loops
street_graph %<>% simplify()

#' Plot results
# street_graph %>%
  # simplify() %>% 
  # plot(vertex.label=NA, vertex.size=.1,vertex.size2=.1, edge.curved = FALSE)
# 

#' COmpute some centrality measures
eig = eigen_centrality(street_graph, weight=E(street_graph)$weight)$vector
deg = degree(street_graph)
bet = betweenness(street_graph, weight=E(street_graph)$weight, normalized = TRUE)
close = closeness(street_graph, weight=E(street_graph)$weight, normalized = TRUE)

V(street_graph)$degree = deg
V(street_graph)$closeness = close
V(street_graph)$betweenness = bet
V(street_graph)$eigen = eig


#' Save closeness centrality as an image (no need to run it)
# closeness_discrete = cut(close, 
#                          breaks =c(quantile(close, probs = seq(0, 1, .1), max(close)), na.rm=TRUE),
#                          right = FALSE,include.lowest=T) 
# 
# pallete = rev(brewer.pal(n = length(levels(closeness_discrete)), "RdYlBu"))
# i = 1
# for (level in levels(closeness_discrete)){
#   print(i)
#   print(level)
#   level_nodes =  V(street_graph)[closeness_discrete == level]
#   E(street_graph)[ from(level_nodes) ]$color <- pallete[i]
#   i = i + 1
# }
# 
# png("doc/plots/road_network_centrality_filtered.png",width = 3000, height=3000, res=500, bg = "black")
# plot(street_graph, vertex.label=NA, vertex.size=.1,vertex.size2=.1, vertex.frame.color=NA, 
#      edge.curved = FALSE, edge.color = E(street_graph)$color, edge.width = .4)
#      # vertex.color = graphCol(close)(close), )
# dev.off()


#' Create SpatialPoints from nodes
#' 
intersections_data_frame = get.data.frame(street_graph, what="vertices")

coordinates(intersections_data_frame)= ~ x +y
proj4string(intersections_data_frame ) = CRS("+proj=utm +zone=32 +datum=WGS84 +units=m")
intersections_data_frame %<>% spTransform(CRS("+init=epsg:4326"))

#' Save SpatialPointsDataFrame
writePointsShape(intersections_data_frame, "data/OSM/streets/street_intersections.shp")

##' Convert back the graph object to a shapefile
#' Create data frame with the information for all edges
street_data_frame = as_data_frame(street_graph)
street_data_frame %<>% 
  mutate(closeness = (vertex_attr(street_graph, "closeness", to)+
          vertex_attr(street_graph, "closeness", from))/2,
          betweenness = (vertex_attr(street_graph, "betweenness", to)+
                         vertex_attr(street_graph, "betweenness", from))/2,
          degree = (vertex_attr(street_graph, "degree", to)+
                           vertex_attr(street_graph, "degree", from))/2,
          eigen = (vertex_attr(street_graph, "eigen", to)+
                     vertex_attr(street_graph, "eigen", from))/2,
          from.lon =vertex_attr(street_graph, "x", from),
          from.lat =vertex_attr(street_graph, "y", from),
          to.lon =vertex_attr(street_graph, "x", to),
          to.lat =vertex_attr(street_graph, "y", to)
          )%>% 
  add_rownames("id")

#' Create SpatialLinesDataFrame
lines_list = apply(street_data_frame, 1,function(row){
  Lines(
    Line(
    rbind(as.numeric(c(row["from.lon"], row["from.lat"])),
          as.numeric(c(row["to.lon"], row["to.lat"])))
  ),
  ID= row["id"])
})

spatial_lines = SpatialLines(lines_list)
lines_df = SpatialLinesDataFrame(SpatialLines(lines_list), data=as.data.frame(street_data_frame))
proj4string(lines_df) = CRS("+proj=utm +zone=32 +datum=WGS84 +units=m")

lines_df %<>% spTransform(CRS("+init=epsg:4326"))


 
#' Plot result into a map
palette <- rev(brewer.pal(10, "RdYlBu")) #Spectral #RdYlBu

roadPal = function(x) {colorQuantile(palette = palette, domain = x, n=10)}

close_map = leaflet(lines_df) %>%
  addProviderTiles("CartoDB.DarkMatter") %>%
  addPolylines(weight = 1, color=~roadPal(closeness)(closeness))
close_map
bet_map = leaflet(lines_df) %>%
  addProviderTiles("CartoDB.DarkMatter") %>%
  addPolylines(weight = 1, color=~roadPal(betweenness)(betweenness)) 
# vertex.color = graphCol(close)(close), )
bet_map
saveWidget(close_map, paste(getwd(),"/doc/plots/street_closeness.html", sep=""), selfcontained = TRUE)
saveWidget(bet_map, paste(getwd(),"/doc/plots/street_betweeness.html", sep=""), selfcontained = TRUE)


#' Save SpatialLinesDataFrame
writeLinesShape(lines_df, "data/OSM/streets/streets.shp")
