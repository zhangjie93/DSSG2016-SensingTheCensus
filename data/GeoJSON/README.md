# GeoJSON Data

The following files are aboud boundaries of Milan's cell-tower grid and census tract.

- milano-grid.geojson
- milano_census_ace.geojson
- milano_census_sez.geojson

"milano-grid.geojson" is available at CDR data distribution page: https://dandelion.eu/datamine/open-big-data/
The rest of the geojson files (census tracts) is avaiable at Italian Census website: http://www.istat.it/it/archivio/104317


Files starting with "CDR_" are CDR data aggregated based on day and time, and are generated from a Python code: https://github.com/myeong/DSSG2016-SensingTheCensus/blob/cdr-geojson/src/notebooks/2016-06-30-cdr-process-by-time.ipynb

The code here is to process only two files, but the actual data are generated by iterating all the data files in the dataset. 

