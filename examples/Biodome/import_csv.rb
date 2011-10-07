#!/usr/bin/env ruby
require "rubygems"
require "mysql"

# eg:  import.rb system01.csv system2.csv system3.csv


/*

CREATE TABLE `log` (
  `timestamp` int(11) unsigned NOT NULL,
  `state` int(1) NOT NULL,
  `temp` float NOT NULL,
  `humidity` float NOT NULL,
  `ambient_temp` float NOT NULL,
  `ambient_humidity` float DEFAULT NULL,
  `control_room_temp` float DEFAULT NULL,
  PRIMARY KEY (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 

*/

#Very strict in its expectations of valid CSV
begin
  #connect to the MySQL server
  dbh = Mysql.real_connect("localhost", "root", "", "growlog")
  #get server version string and display it
  puts "MySQL Server version: " + dbh.get_server_info

  #process files
  ARGF.lines do |line|
    puts "Processing " + ARGF.filename if ARGF.lineno == 1
    col= line.split(",")
    #puts val
    # should chunk this into larger single inserts. One day. Whatevs.

    sql = <<-SQL
        INSERT INTO log (timestamp, state, temp, humidity, ambient_temp, ambient_humidity, control_room_temp)
        VALUES (#{col[0]}, #{col[1]}, #{col[2]}, #{col[3]}, #{col[4]}, #{col[5]}, #{col[6]})
    SQL
    dbh.query(sql)
  end
  puts "Number of rows inserted: #{dbh.affected_rows}"

rescue Mysql::Error => e
  puts "Error code: #{e.errno}"
                puts "Error message: #{e.error}"
                puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
    ensure
  # disconnect from server
  dbh.close if dbh
end
