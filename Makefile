PROJECT = grey_bird
DEPS = cowboy
dep_cowboy = git https://github.com/ninenines/cowboy master
DEPS = mysql
dep_mysql = git https://github.com/mysql-otp/mysql-otp 0.8.1
include ./erlang.mk
