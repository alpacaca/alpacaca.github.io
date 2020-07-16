---
title: Redis（二）
date: 2020-4-1
tags: [中间件, Redis]
---
{% asset_img image1.jpg Redis%}

# Redis（二）
<!--more-->



## 4 Redis 事务控制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;所谓 Redis 事务，就是指一次执行一组指令，Redis 可以保证原子性和隔离性：

- 事务是一个单独的隔离操作：**事务中的所有命令都会序列化、按顺序地执行。**事务在执行的过程中，不会被其他客户端发送来的命令请求所打断。
- 事务是一个原子操作：事务中的命令要么全部被执行，要么全部都不执行。（事实上，Redis 并不能很好的保证事务的原子性，因为不支持回滚和 EXEC 执行错误处理）。

Redis 使用 MULTI、EXEC、DISCARD、WATCH 和 UNWATCH 负责事务的使用，其具体使用周期如下：

1. 使用 MULTI 标记事务开启，之后的命令都将被视为事务内的命令，直到调用 EXEC 或 DISCARD；
2. EXEC 提交事务，Redis 将事务内命令逐一入队并持久化，保证不会受到内存异常或其他指令的影响，按顺序依次执行；
3. DISCARD 丢弃事务，一直到 MULTI 部分的指令都不会执行。
4. WATCH 监控重要的 key ，相当于对关键key加锁，如果在事务提交前 key 被修改，那么本次事务不会提交。
5. UNWATCH 用于取消监控命令，即撤销锁。



**异常情况**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果发生在 [EXEC](http://www.redis.cn/commands/exec.html) 执行之前的错误，客户端会检查命令入队所得的返回值：如果命令入队时返回 `QUEUED` ，那么入队成功；否则，入队失败。服务器会对命令入队失败的情况进行记录，并在客户端调用 [EXEC](http://www.redis.cn/commands/exec.html) 命令时，拒绝执行并自动放弃这个事务。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**在 EXEC 命令执行之后所产生的错误， 并没有对它们进行特别处理： 即使事务中有某些命令在执行时产生了错误， 事务中的其他命令仍然会继续执行 —— Redis 不会停止执行事务中的命令。。**



**Redis 为何不支持回滚**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis 官方勉强的解释如下：

> The Redis command will only fail because of the wrong syntax (and these problems cannot be found when entering the team), or the command is used on the wrong type of key: that is, from a practical point of view, the failed command It is caused by programming errors, and these errors should be discovered during the development process, and should not appear in the production environmen

从实用性的角度来讲，失败的命令是由编程错误造成的，这些错误应该在开发过程中被发现，而不应该出现在生产环境中。

> Because there is no need to support rollback, Redis internals can be kept simple and fast.

因为不需要对回滚进行支持，所以 Redis 的内部可以保持简单且快速。



**使用事务**

```txt
# 开启和提交事务
127.0.0.1:6379> multi
OK
127.0.0.1:6379> rpush list 1 2 3
QUEUED
127.0.0.1:6379> lpush list 0 -1
QUEUED
127.0.0.1:6379> rpoplpush list list_tmp
QUEUED
127.0.0.1:6379> lrange list 0 -1
QUEUED
127.0.0.1:6379> lrange list_tmp 0 -1
QUEUED
127.0.0.1:6379> exec
1) (integer) 3
2) (integer) 5
3) "3"
4) 1) "-1"
   2) "0"
   3) "1"
   4) "2"
5) 1) "3"

# 放弃事务
127.0.0.1:6379> multi
OK
127.0.0.1:6379> set key1 value1
QUEUED
127.0.0.1:6379> set key2 value2
QUEUED
127.0.0.1:6379> discard
OK

# 事务不支持原子性示例
127.0.0.1:6379> multi
OK
127.0.0.1:6379> rpush list 1 2 3
QUEUED
127.0.0.1:6379> lset list 3 0
QUEUED
127.0.0.1:6379> lrange list 0 -1
QUEUED
127.0.0.1:6379> exec
1) (integer) 3
2) (error) ERR index out of range
3) 1) "1"
   2) "2"
   3) "3"
```

使用 WATCH 进行加锁，UNWATCH 解锁

```txt
# 在 watch 监控 money 后 ，创建事务标记前修改 money 值
127.0.0.1:6379> set money 100
OK
127.0.0.1:6379> watch money
OK
127.0.0.1:6379> set money 50
OK
127.0.0.1:6379> multi
OK
127.0.0.1:6379> set money 10
QUEUED
127.0.0.1:6379> get money
QUEUED
127.0.0.1:6379> exec
(nil)
127.0.0.1:6379> unwatch
OK
```

Watch 采用乐观锁策略， Watch 对监控对象加锁时会记录 version，每一次的修改都会创建不同的 version，在事务提交前会比较 version 与初始是否一致，如果不一致则证明被修改，放弃本次事务提交



## 5 Redis 持久化

> redis 计划将 RDB 和 AOF 两种持久化模型合并为一种。（长期计划）

### 5.1 RDB

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis Database（RDB）是 Redis 提供的一种通过 **快照** 技术实现数据持久化的功能，可以通过配置在指定时间间隔内将内存中的数据集快照写入磁盘中的二进制文件，默认使用 dump.rdb 文件。它提供了三种触发机制：

1. 通过配置文件自动触发 （bgsave 指令）:

```bash
### RDB 配置 ###
# 采用异步非阻塞的 bgsave 命令
save 900 1		# 如果 900s 内有至少1个 key 被修改，执行持久化操作
save 300 10		# 如果 300s 内有至少10个 key 被修改，执行持久化操作
save 60 10000	# 如果 60s 内有至少10000个 key 被修改，执行持久化操作

persistence-available [(yes)|no] # 是否持久化，在windows下可以关闭，会重定向到堆分配
stop-writes-on-bgsave-error yes # 持久化错误是否继续工作
rdbcompression yes	# 是否亚索 rdb 文件 （消耗cpu资源）
rdbchecksum yes	# rdb文件校验
dbfilename dump.rdb	# rdb 文件名
dir ./	# rdb文件保存路径
```



2. 通过 save 命令触发，该命令是同步阻塞式的，即执行save命令期间，Redis不能处理其他命令，直到RDB过程完成为止，执行完成时候如果存在老的RDB文件，就会被替换掉。
3. 通过 bgsave 命令触发，该命令是异步非阻塞式的，原理是 redis 主进程通过 fork 创建一个子进程，持久化的任务就交给子进程来完成

{% asset_img 1.png Redis%}



**RDB 的优点：**

1. RDB文件紧凑，全量备份，非常适合用于进行备份和灾后恢复。例如，您可能希望在最近的24小时内每小时存档一次RDB文件，并在30天之内每天保存一次RDB快照。可以轻松还原数据集的不同版本。

3. RDB持久化时主进程唯一需要做的就是 fork 一个子进程，通过子进程完成持久化，父进程永远不会执行磁盘I / O或类似操作。

4. RDB 在恢复大数据集时的速度比 AOF 的恢复速度要快（RDB 是数据导入，AOF 是指令回放）。



**RDB 的缺点：**

1. 在快照开始时子进程共享父进程内存快照数据，但持久化期间父进程修改的数据不会被子进程探知，如果期间发生意外，则这部分数据将会丢失。
2. 在大数据量且 CPU 负载运行时，频繁的 fork 会造成 CPU 的开销。‘



> 注意：
>
> 1. BGSAVE 执行期间会拒绝 SAVE 和 BGSAVE 命令。
> 2. 服务启动后会载入 rdb 文件，在此期间主进程处于阻塞状态。



### 5.2 AOF

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;RDB 在持久化开始时总是统计全量数据集并产生快照，这相对会花费一些时间，并且系统异常时数据丢失率高，AOF （Append Only File）可以作为恰当的替代方案，其原理类似于 MYSQL 的 bin.log 文件，每当 Redis 接收到写命令（set、lpush、lpop等） 时都会通过 write 函数将该命令追加到文件中，形成一个指令日志文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;可以预见到，无论哪种 AOF 同步策略最终都会导致 aof 文件越来越大，redis 提供了一种 **重写方案** ——通过 `bgrewriteaof` 命令将内存中数据重写，其原理类似于 RDB 的快照原理：redis 主进程 fork 子进程，子进程收集内存全量数据集，**以命令的形式重写数据到 aof 文件中**，旧文件将被替换。

{% asset_img 2.png Redis%}

AOF 通过配置提供了三种同步策略：

```bash
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
```



在 Redis 灾后恢复时，通过将 aof 全量指令回放来完成数据的恢复。



**AOF 的优点：**

1. AOF 一般采用每秒同步策略，异常情况时数据丢失率低。
2. AOF 文件写入性能高，没有任何磁盘寻址开销。
3. AOF 智能的通过重写功能减少文件体量堆积。



## 6 Redis 实现订阅-发布

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis 可以作为消息中间件实现标准的消息 **订阅-发布** 功能：在分布式环境中，单节点的 redis 既可以作为接收消息的客户端（Subscriber）也可以作为发布消息的服务器（Publisher），在 sub 和 pub 之间存在消息传递的频道 channel，订阅者面向频道发起订阅并从频道接收下发的消息；同样的，发布者也针对频道下发，又频道负责消息分发。

{% asset_img 3.png Redis%}

{% asset_img 4.png Redis%}

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis 通过 PSUBSCRIBE 、PUBSUB、 PUBLISH、PUNSUBSCRIBE、 SUBSCRIBE、 UNSUBSCRIBE 六个指令完成消息的订阅和发布功能

- PSUBSCRIBE ：订阅一个或多个匹配的频道；
- PUBSUB ：查看订阅与发布系统状态；
- PUBLISH ：将信息发送到指定的频道；
- PUNSUBSCRIBE ：退订所有匹配的频道；
- SUBSCRIBE ：订阅指定的一个或多个频道；
- UNSUBSCRIBE  ：退订指定的频道



**演示**

1. 本地开启三个客户端窗口，其中选定两个为 subscriber，一个为 publisher。

```bash
# sub1 订阅频道 msg_channel
127.0.0.1:6379> subscribe msg_channel
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "msg_channel"
3) (integer) 1

# sub2 订阅频道 news_channel
127.0.0.1:6379> subscribe news_channel
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "news_channel"
3) (integer) 1

# pub
127.0.0.1:6379>
```



2. 两个订阅者都订阅了 msg_channel 频道并处于消息监听状态，接下来 publisher 准备发送消息。

```bash
# pub 向 msg_channel频道和news_channel频道分别下发两条消息消息
127.0.0.1:6379> publish msg_channel "This is first message from three body"
127.0.0.1:6379> publish msg_channel "dont repeat! dont repeat!! dont repeat!!!"
127.0.0.1:6379> publish news_channel "Kobe was a pity"
127.0.0.1:6379> publish news_channel "R.I.P"

# sub1
127.0.0.1:6379> subscribe msg_channel
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "msg_channel"
3) (integer) 1
1) "message"
2) "msg_channel"
3) "This is first message from three body"
1) "message"
2) "msg_channel"
3) "dont repeat! dont repeat!! dont repeat!!!"

# sub2
127.0.0.1:6379> subscribe news_channel
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "news_channel"
3) (integer) 1
1) "message"
2) "news_channel"
3) "Kobe was a pity"
1) "message"
2) "news_channel"
3) "R.I.P"
```



**原理**：在 redis 发布订阅模块下维护了一组 **字典** ，该字典即为频道，里面记录的频道名和订阅者信息，发布者向频道发送消息，该消息又订阅模块接收并通过字典获得所有订阅者并分发。