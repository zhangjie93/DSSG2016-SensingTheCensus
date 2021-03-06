library(raster)  
library(rgdal)  
library(rgeos) 
library(spdep)
library(magrittr)
library(dplyr)
library(ggplot2)
library(gstat)
library(sp)
library(tidyr)
library(readr)
library(corrplot)
library(maptools)

source("src/R/amenity-aggregation-info.R")

mexicoproj = CRS("+proj=lcc +lat_1=17.5 +lat_2=29.5 +lat_0=12 +lon_0=-102 +x_0=2500000 +y_0=0 +ellps=GRS80 +units=m +no_defs")
#read mexico census data
census = readOGR("data/census/mexico_city/mexico_city_census.shp", "mexico_city_census")
proj4string(census) = mexicoproj

#read mexico OSM amenity data
amenities = readOGR("data/OSM/mexico_city/amenities.shp", "amenities")
amenities %<>% spTransform(mexicoproj)

#convert to dataframe
amenities %<>% as.data.frame()

#aggregate and filter OSM amenity categories 
amenities %<>% filter(!amenity %in% remove) %>% 
  mutate(amenity =  as.character(amenity)) %>%
  mutate(
    amenity=ifelse(amenity %in% bank, "bank", 
            ifelse(amenity %in% casino, "casino",
            ifelse(amenity %in% community_center, "community_center",
            ifelse(amenity %in% hospital, "hospital",
            ifelse(amenity %in% marketplace, "marketplace",
            ifelse(amenity %in% parking, "parking",
            ifelse(amenity %in% place_of_worship, "place_of_worship",
            ifelse(amenity %in% toilet, "toilet",
            ifelse(amenity %in% waste, "waste", 
            ifelse(amenity %in% bicycle, "bicycle",
            ifelse(amenity %in% bar, "bar", 
                   amenity))))))))))))

#convert to spatialpoints
coordinates(amenities) = ~coords.x1+coords.x2
proj4string(amenities) = mexicoproj
intersection = raster::intersect(y = census, x = amenities)

#intersect amenity and census data
count_cat = intersection@data %>% group_by(CVE_GEOAGE, amenity) %>% dplyr::summarize(count_cat = n()) 
count_geo = count_cat %>% group_by(CVE_GEOAGE) %>% dplyr::summarize(count_geo = n()) 
total_poi = dim(intersection@data)[1]
#intersection@data[1]
total_poi_cat = intersection@data %>% group_by(amenity) %>% dplyr::summarize(poi_cat = n()) 

#calculate offering advantage 
offer_advantage = count_cat %>% 
  left_join(count_geo, by ="CVE_GEOAGE") %>% 
  left_join(total_poi_cat, by ="amenity") %>%
  mutate(total_poi = total_poi) %>%
  mutate(offer_advantage = (count_cat/count_geo)*(total_poi/poi_cat))

offer_advantage_wide = offer_advantage%>% dplyr::select(CVE_GEOAGE, amenity, offer_advantage) %>% 
  spread(amenity, offer_advantage, fill = 0)


#join census and amenity data 
census@data %<>% left_join(offer_advantage_wide, by = "CVE_GEOAGE")
census@data[is.na(census@data)] <- 0
# dudi = dudi.pca(census@data %>% dplyr::select(IMU, arts_centre:waste),scannf = FALSE)

#calc correlation
corr_depriv_cat = cor(census@data %>% mutate(well_being = IMU) %>% dplyr::select(well_being),
                      census@data %>% dplyr::select(arts_centre:waste))
corr_depriv_cat = data.frame(corr_depriv_cat)

#pca analysis and biplot
osm_pca = census@data %>% dplyr::select(arts_centre:waste) %>% prcomp( center = TRUE, scale = TRUE)
variance <- apply(osm_pca$x, 2, var)  
osm_pca_df = as.data.frame(osm_pca$x[,1:36])
props <- variance / sum(variance)
cum_variance = cumsum(props)
biplot(osm_pca)
summary(osm_pca)
#create csv of amenity, pca, and deprivation
census@data %<>% bind_cols(osm_pca_df)
census@data %>% dplyr::select(CVE_GEOAGE, starts_with("PC"), arts_centre:waste) %>% 
  write_csv("data/OSM/mexico_city/mexico_amenity_pca.csv")


correlationamenity = cor(offer_advantage_wide[,2:54])
corrplot(correlationamenity, method = "color", tl.col="black", number.font=1, col= colorRampPalette(c("red", "white", "blue"))((14)))
corr_df = correlationamenity %>% as.data.frame()%>% add_rownames("var1") %>% gather(var2,cor,arts_centre:waste) %>% arrange(desc(cor))
write.csv(corr_df, "data/mexico_corr_df.csv")

#extract osm public_transport data - reread data in 
public_transport = read.csv("data/OSM/mexico_city/public_transport.csv")
coordinates(public_transport) = ~lon+lat
proj4string(public_transport) = (CRS("+proj=longlat"))

#reproject census data
census %<>% spTransform(CRS("+proj=longlat"))
public_transport %<>% spTransform(CRS("+proj=longlat"))

#intersect public transport with census
intersection = raster::intersect(y = census, x = public_transport)
plot(intersection)

#calculate offering advantage
count_ace_cat = intersection@data %>% group_by(IMU, public_transport) %>% dplyr::summarize(count_ace_cat = n()) 
count_ace = count_ace_cat %>% group_by(IMU) %>% dplyr::summarize(count_ace = n()) 
total_poi = dim(intersection@data)[1]
total_poi_cat = intersection@data %>% group_by(public_transport) %>% dplyr::summarize(poi_cat = n()) 

offer_advantage = count_ace_cat %>% 
  left_join(count_ace, by ="IMU") %>% 
  left_join(total_poi_cat, by ="public_transport") %>% 
  mutate(total_poi = total_poi) %>%
  mutate(offer_advantage = (count_ace_cat/count_ace)*(total_poi/poi_cat))
offer_advantage_wide = offer_advantage%>% dplyr::select(IMU, public_transport, offer_advantage) %>% spread(public_transport, offer_advantage, fill = 0)

census@data %<>% left_join(offer_advantage_wide, by = "IMU")

#export as a csv
write_csv(census@data %>% dplyr::select(IMU, platform:yes),
          "data/OSM/mexico_city/offering_advantage_public_transport_mexicocity.csv")



