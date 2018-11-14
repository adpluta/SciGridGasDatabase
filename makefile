######################################
#        makefile-SCIGRID db         #
######################################


config:=default_config.mk
include $(config)

#=================================================================================#
#              Environment Variables used by psql and createdb                    #
# http://www.postgresql.org/docs/9.3/static/libpq-envars.html                     #
# http://www.postgresql.org/docs/9.3/static/app-createdb.html                     #
#=================================================================================# 

export PGCLUSTER=$(postgres_cluster)
export PGDATABASE=$(postgres_database)
export PGUSER=$(postgres_user)
export PGPORT=$(postgres_port)
export PGHOST=$(postgres_host)
export PGHOSTADDR=$(postgres_host)
export PGPASSWORD=$(postgres_password)
export JAVACMD_OPTIONS=-Djava.io.tmpdir=$(osmosis_tmp_folder)
#export tablename=test


TOPOLOGY_CSV:=  $(network_folder)/vertices_$(postgres_database).csvdata $(network_folder)/vertices_ref_id_$(postgres_database).csvdata
TOPOLOGY_PLOT:= $(visualization_folder)/01_topology_$(postgres_database).png
#####################################################################################

######################to be adapted##################################################
help:
	@echo 'Makefile for a pelican Web site                                           '
	@echo '                                                                          '
	@echo 'Usage:                                                                    '
	@echo '   make html                           (re)generate the web site          '
	@echo '   make clean                          remove the generated files         '
	@echo '   make regenerate                     regenerate files upon modification '
	@echo '   make publish                        generate using production settings '
	@echo '   make serve [PORT=8000]              serve site at http://localhost:8000'
	@echo '   make serve-global [SERVER=0.0.0.0]  serve (as root) to $(SERVER):80    '
	@echo '   make devserver [PORT=8000]          start/restart develop_server.sh    '
	@echo '   make stopserver                     stop local server                  '
	@echo '   make ssh_upload                     upload the web site via SSH        '
	@echo '   make rsync_upload                   upload the web site via rsync+ssh  '
	@echo '   make dropbox_upload                 upload the web site via Dropbox    '
	@echo '   make ftp_upload                     upload the web site via FTP        '
	@echo '   make s3_upload                      upload the web site via S3         '
	@echo '   make cf_upload                      upload the web site via Cloud Files'
	@echo '   make github                         upload the web site via gh-pages   '
	@echo '                                                                          '
	@echo 'Set the DEBUG variable to 1 to enable debugging, e.g. make DEBUG=1 html   '
	@echo 'Set the RELATIVE variable to 1 to enable relative urls                    '
	@echo '                                                                          '



# Step5: Save the network topology as CSV files
topology: log/abstraction.done
	@echo "\n### Saving network topology as CSV files to folder '$(network_folder)' and creating a topology plot:"
	@date >> log/abstraction.log
	export PGPASSWORD=$(postgres_password); psql -c "COPY (SELECT * FROM vertices ORDER BY v_id) TO STDOUT WITH CSV HEADER DELIMITER ',' QUOTE '''' ENCODING 'UTF8';" > $(network_folder)/vertices_$(postgres_database).csvdata
	export PGPASSWORD=$(postgres_password); psql -c "COPY (SELECT * FROM links ORDER BY l_id) TO STDOUT WITH CSV HEADER DELIMITER ',' QUOTE '''' ENCODING 'UTF8';" > $(network_folder)/links_$(postgres_database).csvdata
	export PGPASSWORD=$(postgres_password); psql -c "COPY (SELECT * FROM vertices_ref_id ORDER BY v_id) TO STDOUT WITH CSV HEADER DELIMITER ',' QUOTE '''' ENCODING 'UTF8';" > $(network_folder)/vertices_ref_id_$(postgres_database).csvdata
	python2 create_plots.py $(TOPOLOGY_PLOT) --dbpwrd $(postgres_password)
	@date >> log/abstraction.log
	@echo "--> Done. Saving network topology as CSV files and plot."

# Step4: Execute the abstraction script on the database created in step3
log/abstraction.done: log/database_import.done
	@echo "\n### Running the abstraction script SciGRID.py on the database '$(postgres_database)':"
	@date >> log/abstraction.log
	python2 SciGRID.py --dbpwrd $(postgres_password)
	@touch log/abstraction.done
	@date >> log/abstraction.log
	@echo "--> Done. SciGRID abstraction."

# Step3: Export the OSM filtered power data (from step2) to the created database.
log/database_import.done:
	@if [ -e $(OSM_raw_power_data) ]; then echo "\n### Export the OSM filtered power data \n   '$(OSM_raw_power_data)' \nto the database \n   '$(postgres_database)':"; else echo "$(OSM_raw_power_data) does not exist.";  exit 1; fi
	@date >> log/database.log
	export PGPASSWORD=$(postgres_password); if (! psql -lqt | cut -d \| -f 1 | grep -wq $(postgres_database)); \
	then \
	createdb $(postgres_database) >> log/database.log 2>&1; \
	psql -c "CREATE EXTENSION hstore;" >> log/database.log 2>&1; \
	psql -c "CREATE EXTENSION postgis;" >> log/database.log 2>&1; \
	psql -c "CREATE TABLE vertices_ref_id (v_id serial PRIMARY KEY NOT NULL, osm_id bigint, osm_id_typ char, visible smallint);" >> log/database.log 2>&1; \
	if [ -e ../data/03_network/vertices_ref_id.csvdata ] ; \
	then \
	psql -q -c "COPY vertices_ref_id FROM STDIN WITH CSV HEADER DELIMITER ',' QUOTE '''' ENCODING 'UTF8';" < ../data/03_network/vertices_ref_id.csvdata >> log/database.log 2>&1; \
	psql -q -c "SELECT setval('vertices_ref_id_v_id_seq', (SELECT MAX(v_id) FROM vertices_ref_id));" >> log/database.log 2>&1; \
	psql -q -c "UPDATE vertices_ref_id SET visible = '0';" >> log/database.log 2>&1; \
	echo "Created new database and imorted vertices_ref_id.csvdata into table vertices_ref_id."; \
	else \
	echo "Did not find vertices_ref_id.csvdata. \nThus, created new database with an empty vertices_ref_id table. \nBe aware, that the network topology may has different v_id's compared to the SciGRID release v0.2. "; \
	fi \
	else \
	psql -q -c "UPDATE vertices_ref_id SET visible = '0';" >> log/database.log 2>&1; \
	fi
	@date >> log/database.log
	@date >> log/osm2pgsql.log
	export PGPASSWORD=$(postgres_password); $(osm2pgsql_bin) -r pbf --username=$(postgres_user) --database=$(postgres_database) --host=$(postgres_host) --port=$(postgres_port) -s \
	-C $(osm2pgsql_cache) --hstore --number-processes $(osm2pgsql_num_processes) --style $(stylefile) $(OSM_raw_power_data) >> log/osm2pgsql.log 2>&1
	@touch log/database_import.done
	@date >> log/osm2pgsql.log
	@echo "--> Done. Database import."
    


# Step2: Filter the OSM raw data from step1 spatially (polyfile) for OSM raw power data.
filter_OSM:
	@if [ -e $(OSM_raw_data) ]; then echo "\n### Filter the OSM raw data for power data:"; else echo "$(OSM_raw_data) does not exist.";  exit 1; fi
	@date >> log/osmosis.log
	@if [ ! -e $(polyfile) ]; \
	then \
	echo 'Filter OSM raw data for power data without bounding poly-file:'; \
	$(osmosis_bin) \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter accept-relations route=power \
	--used-way --used-node \
	--buffer outPipe.0=route \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter accept-relations power=* \
	--used-way --used-node \
	--buffer outPipe.0=power \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter reject-relations \
	--tag-filter accept-ways power=* \
	--used-node \
	--buffer outPipe.0=pways \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter reject-relations \
	--tag-filter reject-ways \
	--tag-filter accept-nodes power=* \
	--buffer outPipe.0=pnodes \
	--merge inPipe.0=route inPipe.1=power \
	--buffer outPipe.0=mone \
	--merge inPipe.0=pways inPipe.1=pnodes \
	--buffer outPipe.0=mtwo \
	--merge inPipe.0=mone inPipe.1=mtwo \
	--write-pbf file=$(OSM_raw_power_data) >> log/osmosis.log 2>&1; \
	else \
	echo 'Filter OSM raw data for power data and spatially with poly-file:\n $(polyfile)'; \
	$(osmosis_bin) \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter accept-relations route=power \
	--used-way --used-node \
	--bounding-polygon file=$(polyfile) completeRelations=yes \
	--buffer outPipe.0=route \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter accept-relations power=* \
	--used-way --used-node \
	--bounding-polygon file=$(polyfile) completeRelations=yes \
	--buffer outPipe.0=power \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter reject-relations \
	--tag-filter accept-ways power=* \
	--used-node \
	--bounding-polygon file=$(polyfile) completeWays=yes \
	--buffer outPipe.0=pways \
	--read-pbf file=$(OSM_raw_data) \
	--tag-filter reject-relations \
	--tag-filter reject-ways \
	--tag-filter accept-nodes power=* \
	--bounding-polygon file=$(polyfile) \
	--buffer outPipe.0=pnodes \
	--merge inPipe.0=route inPipe.1=power \
	--buffer outPipe.0=mone \
	--merge inPipe.0=pways inPipe.1=pnodes \
	--buffer outPipe.0=mtwo \
	--merge inPipe.0=mone inPipe.1=mtwo \
	--write-pbf file=$(OSM_raw_power_data) >> log/osmosis.log 2>&1; \
	fi
	@touch log/filter.done
	@date >> log/osmosis.log
	@echo "--> Done. OSM filtered power data."


# Step1: Download the OSM raw data.
download: 
	@echo "\n### Download the OSM raw data from \n   '$(OSM_raw_data_URL)' \nand saving it to \n   '$(OSM_raw_data)':"
	@date >> log/download.log
	wget -nv -O $(OSM_raw_data) $(OSM_raw_data_URL) >> log/download.log 2>&1 
	@touch log/download.done
	@date >> log/download.log
	@echo "--> Done. Download OSM raw data."












#=================================================================================#
#              Output Files                                                       #
#=================================================================================# 

#none at the moment


#read Meta Files  
meta:
	python db_edit.py

#replace out_allpoints coord. if the coord in points.csv are more exact
check:
	python db_check_coord.py


createdb:
	@date >> log/database.log
	export PGPASSWORD=$(postgres_password); 
	createdb $(postgres_database) >> log/database.log 2>&1; \
	psql -c "CREATE EXTENSION hstore;" >> log/database.log 2>&1; \
	psql -c "CREATE EXTENSION postgis;" >> log/database.log 2>&1; \
#	psql -c "CREATE TABLE vertices_ref_id (v_id serial PRIMARY KEY NOT NULL, osm_id bigint, osm_id_type char, visible smallint);" >> log/database.log 2>&1;
#	echo "Did not find vertices_ref_id.csvdata. \nThus, created new database with an empty vertices_ref_id table. \nBe aware, that the network topology may has different v_id's compared to the SciGRID release v0.2. "; \
#	psql -q -c "UPDATE vertices_ref_id SET visible = '0';" >> log/database.log 2>&1; \
	@echo "--> Done."

#connect to database for entering SQL commands
connect:
	@date >> log/database.log
	psql -U $(postgres_user) -d $(postgres_database) -h $(postgres_host)
	@echo "--> Done."; \
		
###############MAKE ARCHITECTURE	##########################

cleardb:
	-psql -c "drop table Compressor;"; 
	-psql -c "drop table LNG;"; 
	-psql -c "drop table InterConnection;"; 
	-psql -c "drop table EntryPoints;"; 
	
	-psql -c "drop table KomNet;";
	-psql -c "drop table Coordinates;"; 
	-psql -c "drop table Meta_Compressor;"; 
	-psql -c "drop table Meta_PipeLines;";
	
	-psql -c "drop table out_allpoints;"; 
	
	-psql -c "drop table points;"; 
	-psql -c "drop table StartEndNet;"; 
	

.PHONY: cleardb


############## LOAD POINTS	##########################

compressor:
	$(eval tablename=Compressor)
	@date >> log/database.log
	-rm Input1.csv
	-rm Input2.csv
	awk 'NR>2 {print}' Gas_Compressor.csv >> Input1.csv
	awk  -F';' 'BEGIN{OFS=";"} {print $$1, $$2, $$3, $$4, $$5, $$6, $$7}' Input1.csv >> Input2.csv
	@date >> log/database.log
	@date >> log/database.log
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);"; 
	psql -c "create table $(tablename)_tmp (v_id serial PRIMARY KEY NOT NULL, Name TEXT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	psql -c "\COPY $(tablename)_tmp(Name,Description,Type,Land,lat,lon,exact) FROM 'Input2.csv' DELIMITER ';'CSV HEADER;";
	psql -c "INSERT INTO $(tablename) (v_id, Name, Description , Type, Land , lat , lon , exact) SELECT k1.*  FROM $(tablename)_tmp AS k1 INNER JOIN ( SELECT name, min(exact) exact FROM $(tablename)_tmp GROUP BY name) k2 ON k1.name=k2.name AND k1.exact=k2.exact ORDER BY name;";
	psql -c "drop table $(tablename)_tmp;";
	
lng:
	$(eval tablename=LNG)
	@date >> log/database.log
	-rm Input1.csv
	-rm Input2.csv
	awk 'NR>2 {print}' Gas_LNG.csv >> Input1.csv
	awk  -F';' 'BEGIN{OFS=";"} {print $$1, $$2, $$3, $$4, $$5, $$6, $$7}' Input1.csv >> Input2.csv
	@date >> log/database.log
	@date >> log/database.log
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);"; 
	psql -c "create table $(tablename)_tmp (v_id serial PRIMARY KEY NOT NULL, Name TEXT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	psql -c "\COPY $(tablename)_tmp(Name,Description,Type,Land,lat,lon,exact) FROM 'Input2.csv' DELIMITER ';'CSV HEADER;";
	psql -c "INSERT INTO $(tablename) (v_id, Name, Description , Type, Land , lat , lon , exact) SELECT k1.*  FROM $(tablename)_tmp AS k1 INNER JOIN ( SELECT name, min(exact) exact FROM $(tablename)_tmp GROUP BY name) k2 ON k1.name=k2.name AND k1.exact=k2.exact ORDER BY name;";
	psql -c "drop table $(tablename)_tmp;";

interconnection:
	$(eval tablename=InterConnection)
	@date >> log/database.log
	-rm Input1.csv
	-rm Input2.csv
	awk 'NR>2 {print}' Gas_InterConnectionPoints.csv >> Input1.csv
	awk  -F';' 'BEGIN{OFS=";"} {print $$1, $$2, $$3, $$4, $$5, $$6, $$7}' Input1.csv >> Input2.csv
	@date >> log/database.log
	@date >> log/database.log
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);"; 
	psql -c "create table $(tablename)_tmp (v_id serial PRIMARY KEY NOT NULL, Name TEXT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	psql -c "\COPY $(tablename)_tmp(Name,Description,Type,Land,lat,lon,exact) FROM 'Input2.csv' DELIMITER ';'CSV HEADER;";
	psql -c "INSERT INTO $(tablename) (v_id, Name, Description , Type, Land , lat , lon , exact) SELECT k1.*  FROM $(tablename)_tmp AS k1 INNER JOIN ( SELECT name, min(exact) exact FROM $(tablename)_tmp GROUP BY name) k2 ON k1.name=k2.name AND k1.exact=k2.exact ORDER BY name;";
	psql -c "drop table $(tablename)_tmp;";

entry:
	$(eval tablename=EntryPoints)
	@date >> log/database.log
	-rm Input1.csv
	-rm Input2.csv
	awk 'NR>2 {print}' Gas_EntryPoints.csv >> Input1.csv
	awk  -F';' 'BEGIN{OFS=";"} {print $$1, $$2, $$3, $$4, $$5, $$6, $$7}' Input1.csv >> Input2.csv
	@date >> log/database.log
	@date >> log/database.log
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);"; 
	psql -c "create table $(tablename)_tmp (v_id serial PRIMARY KEY NOT NULL, Name TEXT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	psql -c "\COPY $(tablename)_tmp(Name,Description,Type,Land,lat,lon,exact) FROM 'Input2.csv' DELIMITER ';'CSV HEADER;";
	psql -c "INSERT INTO $(tablename) (v_id, Name, Description , Type, Land , lat , lon , exact) SELECT k1.*  FROM $(tablename)_tmp AS k1 INNER JOIN ( SELECT name, min(exact) exact FROM $(tablename)_tmp GROUP BY name) k2 ON k1.name=k2.name AND k1.exact=k2.exact ORDER BY name;";
	psql -c "drop table $(tablename)_tmp;";
	
coords:
	$(eval tablename=Coordinates)
	@date >> log/database.log
	-rm Input1.csv
	-rm Input2.csv
	awk 'NR>2 {print}' Gas_Coordinates.csv >> Input1.csv
	awk  -F';' 'BEGIN{OFS=";"} {print $$1, $$2, $$3, $$4, $$5, $$6, $$7}' Input1.csv >> Input2.csv
	@date >> log/database.log
	@date >> log/database.log
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);"; 
	psql -c "create table $(tablename)_tmp (v_id serial PRIMARY KEY NOT NULL, Name TEXT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	psql -c "\COPY $(tablename)_tmp(Name,Description,Type,Land,lat,lon,exact) FROM 'Input2.csv' DELIMITER ';'CSV HEADER;";
	psql -c "INSERT INTO $(tablename) (v_id, Name, Description , Type, Land , lat , lon , exact) SELECT k1.*  FROM $(tablename)_tmp AS k1 INNER JOIN ( SELECT name, min(exact) exact FROM $(tablename)_tmp GROUP BY name) k2 ON k1.name=k2.name AND k1.exact=k2.exact ORDER BY name;";
	psql -c "drop table $(tablename)_tmp;";

#load_StartEndMeta:
#	psql -c "create table StartEndMeta(v_id serial PRIMARY KEY NOT NULL, Name TEXT, Type TEXT, Gas CHAR, From TEXT, To TEXT, Start INTEGER, End INTEGER, direction TEXT, laenge INTEGER, durchmesser_mm float,druck_bar INTEGER, max_durchsatz_m3 FLOAT, compressoren INTEGER,kommentare TEXT);";

###################################################

all_points:
	$(eval tablename=out_allpoints)
	psql -c "create table $(tablename) (v_id serial PRIMARY KEY NOT NULL, Name TEXT,Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	
	psql -c "INSERT INTO out_allpoints(Name,Description,Land,lat,lon,exact) SELECT Name,Description,Land,lat,lon,exact FROM compressor WHERE name NOT IN (SELECT Name FROM out_allpoints);";
	psql -c "UPDATE out_allpoints SET Type=ARRAY(SELECT DISTINCT UNNEST(Type || '{C}')) WHERE name IN (SELECT name FROM compressor);";
	
	psql -c "INSERT INTO out_allpoints(Name,Description,Land,lat,lon,exact) SELECT Name,Description,Land,lat,lon,exact FROM lng WHERE name NOT IN (SELECT Name FROM out_allpoints);";
	psql -c "UPDATE out_allpoints SET Type=ARRAY(SELECT DISTINCT UNNEST(Type || '{L}')) WHERE name IN (SELECT name FROM lng);";
	
	psql -c "INSERT INTO out_allpoints(Name,Description,Land,lat,lon,exact) SELECT Name,Description,Land,lat,lon,exact FROM interconnection WHERE name NOT IN (SELECT Name FROM out_allpoints);";
	psql -c "UPDATE out_allpoints SET Type=ARRAY(SELECT DISTINCT UNNEST(Type || '{I}')) WHERE name IN (SELECT name FROM interconnection);";
	
	psql -c "INSERT INTO out_allpoints(Name,Description,Land,lat,lon,exact) SELECT Name,Description,Land,lat,lon,exact FROM entrypoints WHERE name NOT IN (SELECT Name FROM out_allpoints);";
	psql -c "UPDATE out_allpoints SET Type=ARRAY(SELECT DISTINCT UNNEST(Type || '{E}')) WHERE name IN (SELECT name FROM entrypoints);";
	
	psql -c "INSERT INTO out_allpoints(Name,Description,Land,lat,lon,exact) SELECT Name,Description,Land,lat,lon,exact FROM coordinates WHERE name NOT IN (SELECT Name FROM out_allpoints);";
	psql -c "UPDATE out_allpoints SET Type=ARRAY(SELECT DISTINCT UNNEST(Type || '{P}')) WHERE name IN (SELECT name FROM coordinates);";

create_all: compressor lng coords interconnection entry all_points meta check
	
save_all: 
	-rm out_allpoints.csv	
	@date >> log/database.log
	psql -c "\COPY (SELECT * from out_allpoints ORDER by land,name) TO 'out_allpoints.csv' DELIMITER ';'CSV HEADER;";
	psql -c "\COPY (SELECT * from out_allpoints WHERE 'C' = any(Type) ORDER by land,name)  TO 'out_Compressor.csv' DELIMITER ';' CSV HEADER;";
	psql -c "\COPY (SELECT * from out_allpoints WHERE 'E' = any(Type) ORDER by land,name)  TO 'out_Entry.csv' DELIMITER ';' CSV HEADER;";
	psql -c "\COPY (SELECT * from out_allpoints WHERE 'I' = any(Type) ORDER by land,name)  TO 'out_InterConnection.csv' DELIMITER ';' CSV HEADER;";
	psql -c "\COPY (SELECT * from out_allpoints WHERE 'L' = any(Type) ORDER by land,name)  TO 'out_LNG.csv' DELIMITER ';' CSV HEADER;";

all: cleardb create_all save_all

################# LOAD Network	##########################
################# KomNet	##########################
#load_KomNet:

#Creates KomNetPoints table
     #psql -c "create table KomNetpoints(v_id serial PRIMARY KEY NOT NULL, NetworkID FLOAT, lon FLOAT, lat FLOAT,name TEXT);";
		
#	psql -c "create table KomNetpoints (v_id serial PRIMARY KEY NOT NULL, NetworkID FLOAT, Description TEXT, Type CHAR[], Land TEXT, lat FLOAT, lon FLOAT, exact TEXT);";
	
	#psql -c "\COPY KomNetpoints(NetworkID,lon,lat) FROM 'KomNet/KomNet-nodes.csv' DELIMITER ','CSV HEADER;";

	
	###der teil ist noch falsch
	#Update KomNetpoints SET name
	
	#select name from points INTO KomNetpoints.name where lat IN (SELECT lat FROM KomNetpoints) AND lon IN (SELECT lon FROM KomNetpoints);
	
		#select name from points INTO KomNetpoints.name where lat IN (SELECT lat FROM KomNetpoints) AND lon IN (SELECT lon FROM KomNetpoints);
		
#####		
#select name  INTO KomNetpoints from points where lat IN (SELECT lat FROM KomNetpoints) AND lon IN (SELECT lon FROM KomNetpoints);
#
#UPDATE KomNetpoints SET name= SELECT name from points WHERE lat IN (SELECT lat FROM KomNetpoints) AND lon IN (SELECT lon FROM KomNetpoints);

#drop_KomNet:
 # psql -c "drop table Komnet;"; 

################StartEndNet#################################
save_komnet: 
	-rm komnet_out.csv	
	@date >> log/database.log
	psql -c "\COPY KomNetpoints(v_id,NetworkID,lon,lat,name) TO 'komnet_out.csv' DELIMITER ';'CSV HEADER;";

###################################################################

github: 
	git config user.name "Adam.Pluta@dlr.de"
	git push origin master




