###################################################################################
#                                                                                 #
#   Copyright "2015" "NEXT ENERGY"                                                #
#                                                                                 #
#   Licensed under the Apache License, Version 2.0 (the "License");               #
#   you may not use this file except in compliance with the License.              #
#   You may obtain a copy of the License at                                       #
#                                                                                 #
#       http://www.apache.org/licenses/LICENSE-2.0                                #
#                                                                                 #
#   Unless required by applicable law or agreed to in writing, software           #
#   distributed under the License is distributed on an "AS IS" BASIS,             #
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.      #
#   See the License for the specific language governing permissions and           #
#   limitations under the License.                                                #
#                                                                                 #
###################################################################################


################################## IMPORTANT ######################################
#                                                                                 #
#  This configuration file is necessary to run the abstraction algorithm.         #
#                                                                                 #
#  I.   Note that the name of the database has to be unique!                      #
#       If there is another database with the same name the makefile will abort   #
#       with an error message. However, there is a possibiliy to drop the         #
#       database by typing "make drop" in a terminal.                             #
#                                                                                 #
#  II.  Note that for Mac OS systems, the PostgreSQL folder is located in:        #
#       /Library                                                                  #
#                                                                                 #
#  III. Comments are assigned by '#' at the beginning of a line.                  #
#                                                                                 #
###################################################################################

# Please change the following default values according to your system environment

# 1. URL of the OSM raw data (used for OSM raw data download)
OSM_raw_data_URL:=http://planet.osm.org/pbf/brandenburg-latest.osm.pbf

# 2. Name of the OSM raw data file (used for data filtering by osmosis)
OSM_raw_data:=../data/01_osm_raw_data/brandenburg-latest.osm.pbf

# 3. Name of the bounding polygon file (used for data filtering by osmosis)
#    Use other polyfiles for other spatial areas
polyfile:=../data/01_osm_raw_data/germany.poly

# 4. Specify the location of the osmosis binary file and its (alternative) 
#    temporary folder if more disk space is needed when filtering OSM raw data
#    For Mac OS systems it might be /usr/local/bin/osmosis
osmosis_bin:=/home/apluta/Osmosis/bin/osmosis
osmosis_tmp_folder:=/tmp

# 5. Name of the filtered OSM power data file (used for data export by osm2pgsql)
OSM_raw_power_data:=../data/02_osm_raw_power_data/bran_powerlatest.osm.pbf

# 6. Name of the stylefile (used for data export by osm2pgsql)
stylefile:=../data/02_osm_raw_power_data/power.style

# 7. Specify the location of osm2pgsql binary file, the available cache (MB) and 
#    number of processors used by osm2pgsql for power data export to the database
#    For Mac OS systems it might be /usr/bin/osm2pgsql
osm2pgsql_bin:=/usr/bin/osm2pgsql
osm2pgsql_cache:=1600
osm2pgsql_num_processes:=4

# 8. PostgreSQL connection parameters: 
#    The database will be created and hold the filtered OSM power data 
#postgres_cluster:=9.3/main
#postgres_database:=eu_power_160718
#postgres_user:=postgres
#postgres_port:=5432
#postgres_host:=127.0.0.1

postgres_cluster:=9.6/main
postgres_database:=esa_de_sgg_eurogastest_ap
postgres_user:=esa
postgres_port:=5432
postgres_host:=10.160.84.200
postgres_password:=pg3sa




# 9. Location of the network folder (used to save abstracted network data)
network_folder:=../data/03_network

# 10. Location of the visualization folder (used to save visualized network data)
visualization_folder:=../data/04_visualization











