"""     
###################################################################################
#                                                                                 #
#   Copyright "2018" "NEXT ENERGY"                                                #
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
"""
import os
import logging
logging = logging.getLogger(os.path.basename(__file__))
from db_common import dbconn_from_args
import sys
import os


def ct_vertices(cur,conn):
    # Create vertices table.
    sql = """
          DROP TABLE IF EXISTS vertices;
          CREATE TABLE vertices (
          v_id             bigint PRIMARY KEY NOT NULL,
          lon              float,
          lat              float,
          typ              text,
          voltage          text,
          frequency        text,
          name             text,
          operator         text,
          ref              text,
          WKT_SRID_4326    text);
          """
    cur.execute(sql)
    conn.commit()


 
def create_tables(cur,conn):
    # Create all tables
    ct__vertices(cur,conn)

    
    
if __name__ == '__main__':
    try:
        conn       = dbconn_from_args()
        cur        = conn.cursor()
        create_tables(cur,conn)
        logging.info('Tables created.')
    except Exception, e:
        logging.error('Could not create tables in database.', exc_info=True)
        exit(1)
