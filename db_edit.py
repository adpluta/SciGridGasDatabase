import psycopg2
import csv
import lib2to3

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

#cur.execute('select * from allpoints')

tablename=['Meta_Compressor','Meta_EntryPoints','Meta_PipeLines','Gas_PipeLines']

#tablename=['Meta_Compressor']
for x in range(4):
	command='Drop table IF EXISTS ' + tablename[x] 
	cur.execute(command)
	conn.commit()
	with open(tablename[x]+'.csv', 'rb') as csvfile:
		reader = csv.reader(csvfile, delimiter=';')
		line_count=0
		for row in reader:  
		    if line_count==0:
		       print("skip Header 1")
		       first=row
		       line_count+=1
		    elif line_count==1:
		       print("skip Header 2")
		       second=row
		       line_count+=1
		   
		       command='CREATE TABLE '+ tablename[x]+' (v_id serial PRIMARY KEY NOT NULL '
		       for i in xrange(0,len(row)):
		           command=command+', '+first[i]+' '+second[i]
		       command=command+')'   
		       print(command)
		       print("hallo")
		       cur.execute(command)
		       conn.commit()   
		    elif line_count==2:   
		       print("skip Header 3")
		       line_count+=1
		    else:   
		       line_count+=1
		       parms = ("%s," * (len(row)) + " %s")        
		       command1=','.join(first)
		       command2="('"+"','".join(row)+"')"
		       command ="INSERT INTO "+ tablename[x] +"("+command1+") VALUES"
		       print (command + command2)
		       print(line_count)    
		       cur.execute(command + command2.replace("''","NULL"))
		   
	conn.commit()
	i+=1
