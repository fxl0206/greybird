PROJECT = grey_bird
DEPS = cowboy
dep_cowboy = git https://github.com/ninenines/cowboy master
DEPS = mysql_poolboy
dep_mysql_poolboy = git https://github.com/mysql-otp/mysql-otp-poolboy 0.1.0
include ./erlang.mk
