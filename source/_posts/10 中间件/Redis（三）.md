---
title: Redis（三）
date: 2020-4-1
tags: [中间件, Redis]
---
{% asset_img image1.jpg Redis%}

# Redis（三）
<!--more-->



## 7 Redis 主从复制

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;与 RDBMS 含义一致，在分布式 Redis 系统中，存在多个节点，其中会有==少量若干个 Master 节点负责数据写操作，大量 Slave 节点负责数据读操作==，为了保证读写数据的一致性，就需要维护主-从节点的数据复制。默认情况下，Redis 服务都是主节点，并且每个 Slave 节点只能指向一个 Master节点，同时主从复制能且只能是单向传递的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;主从复制的主要作用包括：

1. 数据热备，主从复制实现了数据的热备份，增强了灾后恢复的能力；同时当主节点出现故障，从节点可以代替主节点继续提供服务，提升了系统容错率。
2. 负载均衡，在多数业务写少读多的场景下，通过==主写从读==的形式，大大提高了系统吞吐率。
3. 高可用基础，主从复制能力是提供 Redis 哨兵模式的基础。



**具体的配置和使用**

1. 查看主从复制配置信息

```bash
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:0
master_repl_offset:0
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
```



2. 修改每个节点的配置文件

```bash
port
pidfile
logfile
dbfilename
```



3. 启动三个服务器
4. 由于 redis 服务默认都是 master ，需要配置其中两个为 slave。

```bash
### 通过命令设置主从关系
# 设置127.0.0.1:6380 和 127.0.0.1:6381 是 127.0.0.1:6379的从节点
127.0.0.1:6380> slaveof 127.0.0.1 6379
127.0.0.1:6381> slaveof 127.0.0.1 6379
```

5. 测试主从读写能力

```bash
# master 写，slave 可读
127.0.0.1:6379> set key1 val1
127.0.0.1:6380> get key1
val1
127.0.0.1:6381> get key1
val1

# slave 不可写
127.0.0.1:6380> set key2
nil
127.0.0.1:6381> set key2
nil

# master 断开连接，slave 依旧可读
127.0.0.1:6379> shutdown
127.0.0.1:6380> get key1
val1
127.0.0.1:6381> get key1
val1

# slave 断开重连，依旧可以读取数据
127.0.0.1:6380> shutdown
127.0.0.1:6381> get key1
val1
# 6380 重连成功
127.0.0.1:6380> get key1
val1
#说明：如果是通过命令设置的主从关系只在本次会话中临时有效，如果断开重连就会自动变为 master 而无法获取数据，现实情况中应该通过配置文件设置主从关系，保证永久性有效。
```

从上述例子中可以看到，在从机断线重连后依然可以获得主机所有的内存数据，称为 **全量复制**；当主机新增数据后，从机也能实时获得更新后的数据，称为 **增量复制**。





## 8 Redis 哨兵模式

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从第 7 节主从模式中可以看到一些弊端，假如分布式环境中是一主多从结构，如果主节点故障退出，环境中将无法接收写操作并更新到从节点，这将造成严重的问题。Redis 提供了哨兵模式（Sentinel）用于解决该类问题。



{% asset_img 1.webp Redis%}



### 8.1 哨兵模式原理

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**在哨兵模式中，“哨兵”是一个独立的进程，它通过向集群中的各节点发送心跳信息并等待响应，从而监控运行中的服务的异常。**然而，单“哨兵”作为进程也有出现问题的风险或者集群数量过大时会出现性能问题，所以通常会设立 N 个哨兵进行监控，并且“哨兵”进程间也会互相监控，这称为**“多哨兵模式”**。

1. 当分布式环境中一个 master 节点故障并被其中一个哨兵监视到，系统不会立刻进入 **failover** 状态；因为仅一个哨兵的报告并不能作为最终的决策，称为**主观下线**；
2. 当多个哨兵也检测到故障，并且这些哨兵数量达到某个设定的阈值，那么就会认为该节点确实出现故障，此时所有哨兵就会进行一次投票，推选其中一位哨兵发起 failover 操作，切换该哨兵监控下的某个 slave 为 master 并通过 **发布-订阅** 模式将修改消息下发给各哨兵，再由各哨兵修改自己监控下的节点主从信息，这个过程称为**客观下线**。

{% asset_img 2.webp Redis%}



> 哨兵投票采用[raft算法](http://thesecretlivesofdata.com/raft/)。
>
> 规则：
>
> 1. 所有的哨兵都有被选举权；
>
> 2. 每次哨兵选举后，不管成功与失败，都会计数epoch。
> 3. 在一个epoch内，所有的哨兵都有一次将某哨兵设置为局部领头的机会，并且局部领头一旦设置，在这个epoch内就不能改变。
> 4. 每个发现主服务器进入客观下线的哨兵都会要求其他哨兵选举自己。
> 5. 哨兵选举局部领头的原则是先到先得，后来的拒绝。
> 6. 如果一个哨兵获得的选票大于半数，则成为领头。



### 8.2 哨兵模式配置

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 redis 目录下由 sentinel.conf 文件用于配置哨兵信息。单个哨兵配置信息如下：

```bash
#配置端口
port 26379
#以守护进程模式启动
daemonize yes
#日志文件名
logfile "sentinel_26379.log"
#存放备份文件以及日志等文件的目录
dir "/opt/redis/data"

#监控的IP 端口号 名称 
#sentinel通过投票后认为mater宕机的数量，此处为至少2个
sentinel monitor mymaster 127.0.0.1 6379 2

#心跳策略
#30秒ping不通主节点的信息，主观认为master宕机
sentinel down-after-milliseconds mymaster 30000

#故障转移后重新主从复制，1表示串行，>1并行
sentinel parallel-syncs mymaster 1

#故障转移开始，三分钟内没有完成，则认为转移失败
sentinel failover-timeout mymaster 180000
```

```bash
# 启动哨兵进程命令
root > redis-sentinel sentinel.conf
```



## 9 缓存击穿、穿透、雪崩、污染

{% asset_img 3.png Redis%}

**缓存穿透**：缓存和数据库中都没有真实数据，此时大量访问该无效数据造成系统压力增大，如果攻击者使用缓存穿透持续攻击，将造成持久层崩溃。

> 解决方案
>
> 1. 对无效数据访问后可在缓存创建值为null的返回，并设定较短的过期时间，可以有效避免攻击。
> 2. 业务层添加有效性校验（布隆过滤），拦截较容易识别的风险。

> 布隆过滤器是一种概率型的数据结构，对所有可能查询的参数以hash形式存储，在业务层中添加校验，如果不符合则丢弃，这样有效降低了对持久层的压力。



**缓存击穿**：当缓存数据过期，此时QPS达到峰值并对该数据进行大规模并发访问，造成数据库瞬间访问量骤增导致奔溃。击穿的特点是少量数据过期，之后对这些数据高并发访问。

> 解决方案
>
> 1. 甄别热点数据，采用合适的过期策略如LRU或LFU。
> 2. 在高QPS来临前，设置Redis冷热数据隔离，假如冷数据发生高并发访问，也可以保证从缓存冷数据读取。
> 3. 业务层创建互斥锁，当缓存数据不存在时，可以保证同一类请求只有一个可以访问数据库，其他请求阻塞，访问成功后刷新缓存，使其他请求通过缓存访问。



**缓存雪崩**：缓存数据大量过期，此时业务查询增大，同样导致数据库压力骤增容易发生奔溃。雪崩特点是大量数据过期，之后被大量访问，区别于缓存击穿。

> 解决方案
>
> 1. 设置合理的缓存过期策略和过期时间，可以自定义一个过期时间范围，并将缓存单数据过期时间以哈希方式分散到不同时间范围。
> 2. 数据预热。
> 3. 停用非热点服务。
> 4. 限流降级，当缓存失效后，只允许若干线程访问数据库，其他线程进入阻塞队列等待。



**缓存污染**：系统将不常用的数据从内存移到缓存，造成常用数据的失效，降低了缓存的利用率。缓存容量是弥足珍贵的，容量过大反而容易影响查询效率，所以在有效的空间内保证热点数据很重要。

> 解决策略
>
> 1. 设置合理的过期策略，FIFO、LRU、LFU等。
> 2. 业务层识别，避免大而全的数据添加进缓存中。



## 10 Jedis 和 Lettuce

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Jedis 和 Lettuce 都是 Redis 的 Java Api，Jedis 采用源码直连 redis ，在多线程环境中使用是不安全的，为了避免线程安全问题，使用 Jedis Pool 连接池；而 lettuce 采用 netty 与 redis 通信，其实例可以在多个线程中共享，不存在线程安全问题，所以 SpringBoot 新版本在自动配置类中虽然提供了两种对象，但已默认使用 Lettuce。

`SpringBoot 集成 Redis 可以参阅本站《Spring及源码——SpringBoot（三）》 13 小节`



单机 maven 环境使用 Jedis：

1. 导入依赖

```xml
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>3.2.0</version>
</dependency>

<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>fastjson</artifactId>
    <version>1.2.62</version>
</dependency>
```



2. 连接本地 Redis，首先需要开启本地 redis 服务

> Jedis 提供的 api 方法与 redis 指令保持一致，所以不展开介绍，仅测试使用

```java
public static void main( String[] args ) {
    Jedis jedis = new Jedis("127.0.0.1", 6379);
    System.out.println(jedis.ping());
}
// output
// PONG
// 连接成功
```



3. 其他功能使用

```java
public static void main( String[] args ) {
    Jedis jedis = new Jedis("127.0.0.1", 6379);

    // string
    System.out.println(jedis.flushDB());
    System.out.println(jedis.setnx("name1", "zhangsan"));
    System.out.println(jedis.setex("name2", 50, "lisi"));
    System.out.println(jedis.get("name1"));

    // set
    System.out.println(jedis.sadd("set1", "A", "B", "C", "D", "E"));
    System.out.println(jedis.sadd("set2", "H", "B", "I", "D", "K"));
    System.out.println(jedis.sdiff("set1", "set2"));
    System.out.println(jedis.sunion("set1", "set2"));

    // 对象
    User user = new User("wangwu", "123456");
    JSONObject json1 = new JSONObject();
    json1.put("user", user);
    System.out.println(jedis.set("user", json1.toJSONString()));
    System.out.println("== 输出所有 keys ==");
    jedis.keys("*").forEach(System.out::println);
    System.out.println("== ==");
    System.out.println(jedis.get("user"));

    // 事务
    System.out.println("==== 事务 ====");
    System.out.println(jedis.flushDB());
    System.out.println(jedis.set("money", "100"));
    System.out.println(jedis.watch("money"));
    Transaction tx = jedis.multi();
    try {
        tx.incrBy("money", 5);
        tx.decrBy("money", 33);
        tx.exec();
    } catch (Exception e) {
        tx.discard();
        e.printStackTrace();
    }
    System.out.println(jedis.get("money"));
    System.out.println("========");


    System.out.println(jedis.dbSize());
    System.out.println(jedis.flushAll());
}

static class User {
    private String username;
    private String password;

    public User() {
    }

    public User(String username, String password) {
        this.username = username;
        this.password = password;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
```



