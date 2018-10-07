---
title: mysql-5.7.x zip版详细配置
date: 2018-10-08 00:02:43
tags: mysql
---
{% asset_img mysql.png MySQL %}

# MySQL 5.7.x 解压版配置和服务安装
<!-- more -->

1. 下载5.7.x zip版本MySQL并解压到本地
2. 在文件根目录下新建my.ini文件，并编辑如下内容

```text
[mysqld]

port = 3306
basedir=A:\dev\mysql-5.7.23-winx64
datadir=A:\dev\mysql-5.7.23-winx64\data 

max_connections=200

character-set-server=utf8

default-storage-engine=INNODB

sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES


[mysql]
default-character-set=utf8

```

> <h3>注意：</h3>
> 此时根目录下还不存在data文件，但需要提前配置好datadir

3. 以管理员权限打开cmd，并进入根目录
```
c:\ > cd A:\dev\mysql-5.7.23-winx64

A:\dev\mysql-5.7.23-winx64 > cd bin

```

4. 先执行remove操作删除可能存在的服务，在安装新服务
```
A:\dev\mysql-5.7.23-winx64\bin > mysqld -remove

A:\dev\mysql-5.7.23-winx64\bin > mysqld -instal
```

5. 初始化MySQL服务，并在根目录下创建data目录，并创建初始化用户root
```
A:\dev\mysql-5.7.23-winx64\bin > mysqld --initialize-insecure --user=mysql
```

6. 启动MySQL服务
```
A:\dev\mysql-5.7.23-winx64\bin > net start mysql
```

7. 为root用户创建登录密码

```
A:\dev\mysql-5.7.23-winx64\bin > mysqladmin -u root -p password 新密码
Enter password:
```
由于初始化密码为空，所以第二步骤可以直接enter

8. 登录mysql成功！
```
A:\dev\mysql-5.7.23-winx64\bin > mysql -u root -p 
Enter password:密码

Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 9
Server version: 5.7.23 MySQL Community Server (GPL)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>show databases;
```
<br><br>
# 安装和破解Navicat Premium 12.x

1. 在[这里](https://www.lanzous.com/i1jw6ib)下载64位12.x版本Navicat Premium
2. 在[这里](https://www.lanzous.com/i1jw6oh)下载注册机
3. 正常安装后使用注册机破解
4. 毕竟不是光彩的事情，详情[请戳这里](https://blog.csdn.net/loveer0/article/details/82016644)