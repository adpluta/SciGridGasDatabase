import psycopg2
import csv

import configparser
config = configparser.ConfigParser()
config.read('config.ini')

section='DEFAULT'

dbname_ini=config.get(section,'dbname')
user_ini=config.get(section,'user')
host_ini=config.get(section,'host')
password_ini=config.get(section,'password')
port_ini=config.get(section,'port')

conn = psycopg2.connect(
     dbname=dbname_ini, user=user_ini, port=port_ini,
     host=host_ini, password=password_ini) 
     
     
cur = conn.cursor() 

command='UPDATE out_allpoints AS a SET lat=b.lat, lon=b.lon, exakt=b.exakt FROM punkte AS b WHERE a.name=b.name AND a.exakt > b.exakt'

cur.execute(command)
conn.commit()



