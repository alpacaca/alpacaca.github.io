---
title: Redis（一）
date: 2020-4-1
tags: [中间件, Redis]
---
{% asset_img image1.jpg Redis%}

# Redis（一）
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis 是一个开源的 K-V 结构缓存系统，还支持数据持久化即可以作为数据库和消息中间件使用。它支持多种数据结构：字符串、散列、列表、集合、有序集合等。Redis内置了 LUA 脚本，LRU 驱动事件，事务和不同级别的磁盘持久化，支持通过 Redis 哨兵（Sentinel）和自动分区（Cluster）提供高可用性。

## 1 NoSQL

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NoSQL，泛指非关系型的数据库，为了解决大规模数据集合多重数据种类带来的挑战，尤其是大数据应用难题。具有如下优点：

- 易扩展，NoSQL数据库种类繁多，但是一个共同的特点都是去掉关系数据库的关系型特性；
- 数据之间无关系，这样就非常容易扩展；
- 高性能，NoSQL数据库都具有非常高的读写性能，尤其在大数据量下，同样表现优秀；



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;常用 NoSQL 数据库类型包括： 

- 哈希表数据库，表中有一个特定的键和一个指针指向特定的数据；（Redis）
- 列存储数据库，通常是用来应对分布式存储的海量数据。键仍然存在，但是它们的特点是指向了多个列；(HBase)
- 文档型数据库，数据模型是版本化的文档，半结构化的文档以特定的格式存储，比如JSON。文档型数据库可以看作是键值数据库的升级版，允许之间嵌套键值，在处理网页等复杂数据时，文档型数据库比传统键值数据库的查询效率更高；（MongoDB）
- 图形数据库，它是使用灵活的图形模型（不是保存图），并且能够扩展到多个服务器上。NoSQL数据库没有标准的查询语言(SQL)，因此进行数据库查询需要制定数据模型，使用场景比如社交网络。(Neo4j)



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NoSQL框架体系NosoL整体框架分为四层，由下至上分为数据`持久层(data persistence)`、`整体分布层(data distribution model)`、`数据逻辑模型层(data logical model)`、和`接口层(interface)`，层次之间相辅相成，协调工作。

- **数据持久层**：定义了数据的存储形式，主要包括基于内存、基于硬盘、内存和硬盘接口、订制可拔插四种形式。基于内存形式的数据存取速度最快，但可能会造成数据丢失。基于硬盘的数据存储可能保存很久，但存取速度较基于内存形式的慢。内存和硬盘相结合的形式，结合了前两种形式的优点，既保证了速度，又保证了数据不丢失。订制可拔插则保证了数据存取具有较高的灵活性。
- **数据分布层：**定义了数据是如何分布的，相对于关系型数据库，NoSQL可选的机制比较多，主要有三种形式：一是CAP支持，可用于水平扩展。二是多数据中心支持，可以保证在横跨多数据中心是也能够平稳运行。三是动态部署支持，可以在运行着的集群中动态地添加或删除节点。
- **数据逻辑层：**表述了数据的逻辑变现形式，与关系型数据库相比，NoSQL在逻辑表现形式上相当灵活，参考数据库类型介绍。
- **接口层：**为上层应用提供了方便的数据调用接口，提供的选择远多于关系型数据库。接口层提供了五种选择：Rest，Thrift，Map/Reduce，Get/Put，特定语言API，使得应用程序和数据库的交互更加方便。



NoSQL数据库在以下的这几种情况下比较适用： 

1. 数据模型比较简单；  
2. 需要灵活性更强的IT系统；  
3. 对数据库性能要求较高； 
4. 不需要高度的数据一致性；  
5. 对于给定key，比较容易映射复杂值的环境。



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MongoDB 是一个介于关系数据库和非关系数据库之间的产品，是非关系数据库中功能最丰富，最像关系数据库的。它支持的数据结构非常松散，是类似Json的**Bjson格式**，因此可以存储比较复杂的数据类型。MongoDB最大的特点是支持的查询语言非常强大，其语法有点类似于面向对象的**查询语言**，几乎可以实现类似关系数据库单表查询的绝大部分功能，还支持为数据建立索引。它的特点是高性能、易部署、易使用、存储数据非常方便。



## 2 Redis 配置

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis （Remote Dictionary Server）的关键字：

- C语言编写、支持网络、基于内存、可持久化、K-V数据库、开源，提供多API。
- 数据类型丰富、操作丰富、操作原子性、基于持久化的主从同步。
- 高性能：读110000次/s，写81000次/s。



### 2.1 Redis Windows 安装

1. 下载解压包并解压，配置到环境变量 path，在安装目录下输入命令 `redis-server redis.windows.conf`

2. 安装 windows 服务，`redis-server --service-install redis.windows.conf`，启动服务

   Redis常用的指令
   卸载服务：redis-server --service-uninstall
   开启服务：redis-server --service-start
   停止服务：redis-server --service-stop

3. 通过 set 和 get 测试

```txt
D:\software code\Redis-x64-3.2.100>redis-cli
127.0.0.1:6379> set A 123
OK
127.0.0.1:6379> get A
"123"
```



### 2.2 Redis Linux 安装

1. 解压 tar 包，执行环境安装 `yum install gcc-c++`。
2. 执行 `make`  和 `make install` 安装。
3. 修改配置文件 redis.conf 中 daemonize 为 yes，支持服务自动开启。
4. 开启服务 `redis-server redis.conf`。
5. 查看 redis 进程 `ps -ef | grep redis`。
6. 使用 `shutdown` 关闭服务。



### 2.3 Redis 基础信息

1.  redis 默认有 16 个数据库， 使用第 0 个数据库，`在集群中不支持切换db`

```txt
# 查看数据库大小
127.0.0.1:6379> dbsize
(integer) 0

# 选择数据库
127.0.0.1:6379> select 5
OK

# 清除当前数据库
127.0.0.1:6379[5]> flushdb 
```



2. redis 是单线程，它的效率瓶颈是内存和网络决定，而不是CPU使用率 ，多线程下会存在用户态和内核态切换的事件开销。
3. 设置过期时间及查询。

```txt
127.0.0.1:6379> set name zhangsan
OK
127.0.0.1:6379> keys *
1) "name"

# 设置过期时间
127.0.0.1:6379> expire name 5
(integer) 1

# 查看过期倒计时
127.0.0.1:6379> ttl name
(integer) 3

127.0.0.1:6379> keys *
(empty list or set)
```



### 2.4 配置详解

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; redis.conf 是 redis 核心配置文件，其中定义了 redis 通用配置、分布式配置等等。

```bash
# 导入其他配置文件
include .\path\to\local.conf

### 网络配置 ###
bind 127.0.0.1
port 6379
protected-mode yes 	# 保护模式

### 通用配置 ###
daemonize yes	# 守护进程，默认为 no
loglevel notice # 日志等级 debug、verbose、notice、warning
logfile "" # 具体日志文件
databases 16 # 默认 16 个数据库
pidfile /var/run/reids_6379.pid # 以服务方式运行需指定

### RDB 配置 ###
save 900 1		# 如果 900s 内有至少1个 key 被修改，执行持久化操作
save 300 10		# 如果 300s 内有至少10个 key 被修改，执行持久化操作
save 60 10000	# 如果 60s 内有至少10000个 key 被修改，执行持久化操作

persistence-available [(yes)|no] # 是否持久化，在windows下可以关闭，会重定向到堆分配
stop-writes-on-bgsave-error yes # 持久化错误是否继续工作
rdbcompression yes	# 是否亚索 rdb 文件 （消耗cpu资源）
rdbchecksum yes	# rdb文件校验
dbfilename dump.rdb	# rdb 文件名
dir ./	# rdb文件保存路径

###　AOF 配置 ###
appendonly no # 默认使用 rdb 持久化，不开启 aof 模式
# AOF同步策略
# always 每次写操作都会同步
# everysec 每秒同步一次
# no 不同步
appendfsync always 
appendfilename "appendonly.aof" # aof 文件名
no-appendfsync-on-rewrite no # 重写期间是否同步
auto-aof-rewrite-percentage 100 # 当 aof 达到文件容量的百分比后自动重写
auto-aof-rewrite-min-size 64mb # 当 aof 文件大于文件容量后自动重写


### 主从复制 ###
replicaof <masterip> <masterport> # 设置master节点的地址
masterauth <master-password> # 设置连接主机的密码
replica-serve-stale-data yes
replica-read-only yes # 设置主机只读不写


### 安全 ###
requirepass foobared # 设置redis连接密码，默认无密码，通常通过 `config set requirepass 123`设置

### 约束 ###
maxclients 10000 # 客户端连接最大数，默认无配置
maxmemory <bytes> # redis 最大内存容量

# volatile-lru：使用 LRU 算法移除过期集合内的 key
# allkeys-lru：使用 LRU 算法移除任意 key
# volatile-random：随机从过期集合内移除 key
# allkeys-random：随机移除任意 key
# volatile-ttl：移除接近过期的 key
# noeviction：无策略，写操作时报错
maxmemory-policy noeviction # 当内存达到最大内存时采用的策略，默认不采取策略只返回错误


```





## 3 数据类型详解

**string**

常用命令：set \ get \ append \ strlen \ getrange \ setrange \ incr \ decr \ incrby \ decrby \ setex \ setnx \ mset \ mget \ getset

```txt
### 字符串操作命令 ###
127.0.0.1:6379> set key1 value1
127.0.0.1:6379> append key1 _appendix
127.0.0.1:6379> get key1
"value1_appendix"
127.0.0.1:6379> strlen key1
15

# 追加key不存在则设置为该值
127.0.0.1:6379> append key2 _appendix2
127.0.0.1:6379> get key2
"_appendix2"

# 范围
127.0.0.1:6379> set key1 "this is a string"
127.0.0.1:6379> getrange key1 0 3
"this"
127.0.0.1:6379> getrange key1 0 -1
"this is a string"
# 替换
127.0.0.1:6379> setrange key1 7 " not "
127.0.0.1:6379> get key1
"this is not ring"

# 自增和自减
127.0.0.1:6379> set count 0
127.0.0.1:6379> incr count
127.0.0.1:6379> get count
"1"
127.0.0.1:6379> decr count
127.0.0.1:6379> get count
"0"

# 步长自增
127.0.0.1:6379> incrby count 5
127.0.0.1:6379> get count
"5"

# setnx "set if not exist"
127.0.0.1:6379> setnx key2 redis
127.0.0.1:6379> get key2
"redis"
127.0.0.1:6379> setnx key2 db
127.0.0.1:6379> get key2
"redis"

# 批量处理
127.0.0.1:6379> mset key1 v1 key2 v2 key3 v3
127.0.0.1:6379> mget key1 key2 key3
1) "v1"
2) "v2"
3) "v3"

# 保存对象
127.0.0.1:6379> set user1 {name:zhangsan,sex:false}
127.0.0.1:6379> get user1
"{name:zhangsan,sex:false}"

# 组合操作
127.0.0.1:6379> getset current 123
(nil)
127.0.0.1:6379> get current
"123"
127.0.0.1:6379> getset current 456
"123"
127.0.0.1:6379> get current
"456"
```



**list**

可以通过 list 模拟很多基础数据类型比如 栈、 队列、双端队列等。

常用命令：lpush / rpush / lpop / rpop / lrange / llen / lrem / lset / lindex / rpoplpush / linsert

```txt
### list 命令 ###
# 左入右入
127.0.0.1:6379> lpush list1 1 2 3 4 5
127.0.0.1:6379> lrange list1 0 -1
1) "5"
2) "4"
3) "3"
4) "2"
5) "1"
127.0.0.1:6379> rpush list2 1 2 3 4 5
127.0.0.1:6379> lrange list2 0 -1
1) "1"
2) "2"
3) "3"
4) "4"
5) "5"

# 左出右出
127.0.0.1:6379> lpop list1
"5"
127.0.0.1:6379> rpop list2
"5"

# 下标索引
127.0.0.1:6379> flushdb
OK
127.0.0.1:6379> rpush list1 1 2 3
127.0.0.1:6379> lindex list1 1
"2"

# 列表长度
127.0.0.1:6379> llen list1
(integer) 3

# 删除
127.0.0.1:6379> lrem list1 1 3
127.0.0.1:6379> lrange list1 0 -1
1) "1"
2) "2"

127.0.0.1:6379> rpush list2 1 2 3 4 5
127.0.0.1:6379> lrange list2 0 -1
1) "1"
2) "2"
3) "3"
4) "4"
5) "5"
127.0.0.1:6379> ltrim list2 1 3
127.0.0.1:6379> lrange list2 0 -1
1) "2"
2) "3"
3) "4"

# 弹出末尾元素并添加到新列表中
127.0.0.1:6379> rpush list3 1 2 3 4 5
127.0.0.1:6379> rpoplpush list3 list4
"5"
127.0.0.1:6379> lrange list3 0 -1
1) "1"
2) "2"
3) "3"
4) "4"
127.0.0.1:6379> lrange list4 0 -1
1) "5"

# 修改列表元素
127.0.0.1:6379> rpush list1 1
127.0.0.1:6379> lset list1 0 0
OK
127.0.0.1:6379> lrange list1 0 -1
1) "0"

# 插入
127.0.0.1:6379> rpush list1 1 3 5
## 在元素3之前插入2
127.0.0.1:6379> linsert list1 BEFORE 3 2
## 在元素3之后插入4
127.0.0.1:6379> linsert list1 AFTER 3 4
127.0.0.1:6379> lrange list1 0 -1
1) "1"
2) "2"
3) "3"
4) "4"
5) "5"
```



**set**

set 内数据不会重复。

常用命令：sadd \ srem \ smembers \ sismember \ spop \ srandmember \ smove \ scard \ sdiff \ sinter \ sunion

```txt
### set 命令 ###
# 新增和查看
127.0.0.1:6379> sadd set1 "zhangsan" "lisi" "zhangsan"
127.0.0.1:6379> smembers set1
1) "zhangsan"
2) "lisi"

# 判断
127.0.0.1:6379> sismember set1 zhangsan
(integer) 1

# 长度
127.0.0.1:6379> scard set1
(integer) 2

# 删除
127.0.0.1:6379> srem set1  zhangsan
127.0.0.1:6379> smembers set1
1) "lisi"

#随机删除
127.0.0.1:6379> spop set1 1
1) "zhangsan"
127.0.0.1:6379> smembers set1
1) "lisi"

# 随机选取 n 个元素
127.0.0.1:6379> srandmember set1 1
1) "zhangsan"
127.0.0.1:6379> srandmember set1 1
1) "lisi"

# 移动元素
127.0.0.1:6379> sadd set1 zhangsan lisi
127.0.0.1:6379> sadd set2 wangwu
127.0.0.1:6379> smembers set1
1) "zhangsan"
2) "lisi"
127.0.0.1:6379> smembers set2
1) "wangwu"
127.0.0.1:6379> smove set2 set1 wangwu
127.0.0.1:6379> smembers set1
1) "wangwu"
2) "zhangsan"
3) "lisi"
127.0.0.1:6379> smembers set2
(empty list or set)

# 集合操作
127.0.0.1:6379> sadd set1 zhangsan lisi wangwu zhaoliu
127.0.0.1:6379> sadd set2 zhangsan wangwu
# 差集
127.0.0.1:6379> sdiff set1 set2
1) "lisi"
2) "zhaoliu"
# 交集
127.0.0.1:6379> sinter set1 set2
1) "wangwu"
2) "zhangsan"
# 并集
127.0.0.1:6379> sunion set1 set2
1) "lisi"
2) "zhaoliu"
3) "zhangsan"
4) "wangwu"
```



**hash**

常用命令：hset / hget / hmset / hmget / hgetall / hdel / hlen / hexists / hkeys / hvals / hincr / hdecr / hincrby / hdecrby / hsetnx /

使用场景：常应用于对象数据变更

hash 命令同比字符串，不过多介绍



**zset**

zset 是有序集合，使用功能类比 set ，不过多介绍，只介绍排序类。

常用命令：zadd / zrem  / zcard / zrange / zrevrange / zrangebyscore / zrevrangebyscore / zcount

```txt
# 添加
127.0.0.1:6379> zadd ages 18 zhangsan
127.0.0.1:6379> zadd ages 19 lisi
127.0.0.1:6379> zadd ages 21 wangwu
127.0.0.1:6379> zadd ages 17 zhaoliu
# 升序排列
127.0.0.1:6379> zrange ages 0 -1
1) "zhaoliu"
2) "zhangsan"
3) "lisi"
4) "wangwu"
127.0.0.1:6379> zrange ages 0 -1 WITHSCORES
1) "zhaoliu"
2) "17"
3) "zhangsan"
4) "18"
5) "lisi"
6) "19"
7) "wangwu"
8) "21"
# 降序排列
127.0.0.1:6379> zrevrange ages 0 -1
1) "wangwu"
2) "lisi"
3) "zhangsan"
4) "zhaoliu"

# 指定升序排序，inf表示无穷
127.0.0.1:6379> zrangebyscore ages -inf +inf
1) "zhaoliu"
2) "zhangsan"
3) "lisi"
4) "wangwu"
# 指定降序排序
127.0.0.1:6379> zrevrangebyscore ages +inf -inf
1) "wangwu"
2) "lisi"
3) "zhangsan"
4) "zhaoliu"

# 计数
127.0.0.1:6379> zcount ages -inf +inf
(integer) 4 

```



**geospatial**

用于地理位置经纬度的保存。

常用命令：geoadd / geopos / geodist / georadius / georadiusbymember

```txt
# 添加 key longitude latitude name
127.0.0.1:6379> geoadd china:city 116.40 39.90 beijing
127.0.0.1:6379> geoadd china:city 121.47 32.23 shanghai
127.0.0.1:6379> geoadd china:city 108.95 34.263 xian
127.0.0.1:6379> geoadd china:city 114.18 22.27 hongkong

# 获取坐标
127.0.0.1:6379> geopos china:city xian
1) 1) "108.95000249147415"
   2) "34.263000754041961"
   
# 两者直线距离
127.0.0.1:6379> geodist china:city hongkong xian
"1428303.9802"
127.0.0.1:6379> geodist china:city hongkong xian km
"1428.3040"

# 给定坐标（110,30）和半径（500 km），查找范围内元素
127.0.0.1:6379> georadius china:city 110.0 30.0 500 km
1) "xian"

# 以给定本经和元素为中心，超找其他元素
127.0.0.1:6379> georadiusbymember china:city xian 2000 km withcoord
1) 1) "xian"
   2) 1) "108.95000249147415"
      2) "34.263000754041961"
2) 1) "hongkong"
   2) 1) "114.17999893426895"
      2) "22.27000054000478"
3) 1) "shanghai"
   2) 1) "121.47000163793564"
      2) "32.229999766261393"
4) 1) "beijing"
   2) 1) "116.39999896287918"
      2) "39.900000091670925"
```



**hyperloglog**

基数统计算法，重复数只统计一次（基数），在输入元素的数量或者体积非常非常大时，计算基数所需的空间总是固定 的、并且是很小。

> 官方提示，会有 0.81% 的错误率。

比如 UV 统计，单人多次点击 UV 量始终保持 1。

常用命令：pfadd / pfcount / pfmerge

```txt
# 添加元素和统计
127.0.0.1:6379> pfadd key1 a b c d e f g
127.0.0.1:6379> pfadd key2 h i j k l m n
127.0.0.1:6379> pfcount key1 key2
(integer) 14

# 合并
127.0.0.1:6379> pfmerge key3 key1 key2
127.0.0.1:6379> pfcount key3
(integer) 14
```



**bitmaps**

位图，位存储，只记录 0 或 1状态。

使用场景：在二义性的统计中，可以使用位存储，例如统计员工一年总打卡数，就可以将每个员工的一年打开保存为 365 位的 0 元素，打卡的天数表示为 1 。

常用命令：

```txt
# 记录一周的打卡
127.0.0.1:6379> setbit sign 1 1
127.0.0.1:6379> setbit sign 2 1
127.0.0.1:6379> setbit sign 3 1
127.0.0.1:6379> setbit sign 4 1
127.0.0.1:6379> setbit sign 5 1
127.0.0.1:6379> setbit sign 6 0
127.0.0.1:6379> setbit sign 7 0

# 查看某天
127.0.0.1:6379> getbit sign 1
(integer) 1
127.0.0.1:6379> getbit sign 6
(integer) 0

# 统计有 1 的值的数量
127.0.0.1:6379> bitcount sign
(integer) 5
127.0.0.1:6379> bitcount sign 0 -1
(integer) 5
```

