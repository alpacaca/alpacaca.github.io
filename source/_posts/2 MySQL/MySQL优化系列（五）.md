---
title: MySQL优化系列（五）（缓存篇）
date: 2020-3-10
tags: [mysql, MySQL优化, 缓存]
---
{% asset_img image1.jpg MySQL %}





# MySQL优化系列（五）（缓存篇）
<!--more-->

## 4 缓存

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;说明：由于是MySQL优化系列，本篇缓存旨在引导向，并不深入介绍，后续将开篇深入介绍，同样的，作为Java端持久化框架Mybatis、Hibernate和 JPA 也适用此说明，由于JPA基于Hibernate轻量化封装，所以框架缓存策略选择JPA介绍即可。

### 4.1 为什么使用缓存

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;缓存，是以提升数据响应为目的，以合理的缓存策略为条件，以数据中间件的形式为手段的一种技术。在计算机纵向世界，软硬件都有各自的缓存，并且缓存都是以提升现有框架约束的性能为价值，且成为衡量系统性能的重要指标之一。再此我们仅讨论软件领域以内存为驱动模型的缓存。

**缓存的用途**，使用缓存可以减少某条频繁进行数据处理链路上的性能损耗，通常是读多写少的场景，缓存是一种空间换时间的解决方案，通常在内存中进行。

**缓存的位置**，众所周知，在计算机科学发展历史长河中，困难的问题往往都是通过增加第三方中间件来解决的，而缓存的位置随着业务覆盖的不同而不同。

> 比如，在web前端页面，经常会缓存页面渲染或数据处理常用的信息，如多次浏览同一商品的信息，这一功能现代浏览器基本都支持。
>
> 比如，还是web前端，用户通过点击页面按钮多次进行查询，通过http访问后端控制器接口就可以添加相应的缓存，而无需经过服务层乃至持久层查询。
>
> 再比如，数据频繁的读场景，通常是在业务层和持久层中添加缓存，以减少数据库访问带来的IO性能损耗和数据连接开销。

**缓存的分类**，应用开发层面的数据结构如Map，持久层数据中间件如EhCache、Memcache、Redis等，数据库自带的缓存特性如Mysql和Oracle等。

**缓存的策略**，由于不同系统的数据访问模式不同，同一种缓存策略很难在不同的数据访问模式下取得满意的性能，通常使用如下几种策略：

1. 基于访问的时间：按各缓存项被访问时间来组织缓存队列，决定替换对象。如 FIFO，LRU；
2. 基于访问频率：用缓存项的被访问频率来组织缓存。如 LFU、LRU2；
3. 访问时间与频率兼顾：兼顾访问时间和频率，使数据在变化时缓存策略仍有较好性能。多数此类算法具有一个可调或自适应参数，通过该参数的调节使缓存策略在基于访问时间与频率间取得一个平衡，如 FBR；
4. 基于访问模式：某些应用有较明确的数据访问特点，进而产生与其相适应的缓存策略。

> FIFO，First In Last Out，即先进先出，如果一个数据是最先进入的，那么可以认为在将来它被访问的可能性很小，当缓存空间不足，它最先被释放。
>
> LRU：Least Recently Use，即最近最久未使用算法，选择最近最久未使用的数据予以淘汰，在缓存空间内，最近一直没有被使用的数据会被释放，由新访问数据代替
>
> LFU：Least Frequently Used，即最近最少使用算法，如果一个数据在最近一段时间很少（频率）被访问到，那么可以认为在将来它被访问的可能性也很小。因此，当空间满时，最小频率访问的数据最先被释放。
>
> LRU2：Least Recently Used 2，即LRU的改进版本，每当一次缓存记录的使用，会把它放到栈的顶端。当栈满了的时候，再把栈底的对象给换成新进来的对象。
>
> FBR：Frequency-based replacement， 需要可调参数平衡访问时间和频率。

**数据一致性**，当分布式缓存中读写并发执行，有可能导致同一数据先读后写，那么缓存中保存的将是旧数据；先操作数据库，再清除缓存，如果缓存删除失败，就会出现数据不一致问题，解决方案如下：

1. 前者可以采取将读写纳入同一节点的缓存按照同步处理，或者采取数据写入前后一并删除相关缓存。
2. 缓存删除失败，可以将删除失败的key存入队列中并重复删除直到成功为止。

**缓存的指标**，命中率=命中次数/访问次数，命中率是缓存最重要的指标，它直接决定了缓存设计的合理性，若查询一个缓存，十次查询九次能得到正确结果，那么命中率就是90%。而直接影响缓存命中率的因素包含：缓存容量、内存空间和缓存策略。

### 4.2 MySQL缓存

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从前面介绍已经可以了解到，Mysql在执行时需要经过四层逻辑分层（客户端接口 -> 服务 -> 引擎 -> 持久层），并在服务层和插件引擎层还需要经过解析、优化、执行过程，并最终在持久层完成IO操作，这一些列耗时耗力的操作在QPS峰值时是噩梦般的存在，所以Mysql自身也支持缓存策略，在MyIsam中使用缓存策略，在InnoDB中使用缓冲池策略。

```mysql
# 查询是否支持查询缓存
mysql> show variables like 'have_query_cache';
+------------------+-------+
| Variable_name    | Value |
+------------------+-------+
| have_query_cache | YES   |
+------------------+-------+

# 查询当前缓存状态
mysql> show status like '%qcache%';
+-------------------------+-------+
| Variable_name           | Value |
+-------------------------+-------+
| Qcache_free_blocks      | 0     |  缓存空闲的内存块
| Qcache_free_memory      | 0     |  在query_cache_size设置的缓存中的空闲的内存
| Qcache_hits             | 0     |  缓存的命中次数
| Qcache_inserts          | 0     |  查询缓存区此前总共缓存过多少条查询命令的结果
| Qcache_lowmem_prunes    | 0     |  查询缓存区已满而从其中溢出和删除的查询结果的个数
| Qcache_not_cached       | 0     |  
| Qcache_queries_in_cache | 0     |  缓存查询次数
| Qcache_total_blocks     | 0     |  缓存总的内存块
+-------------------------+-------+
```

通过修改mysql配置文件来配置缓存

```txt
[mysqld]
query_cache_type=1 #0不使用，1使用，2适时使用
query_cache_size=10485760 #10M，单位字节
query_cache_limit=1048576 #1M, 单个查询允许使用的最大缓存

```



### 4.3 Memcache和Redis

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;缓存界两位翘楚，都是基于内存的存储机制，亦可称为内存数据库。两者都是高性能的分布式缓存，在缓存层面都可以很好的满足业务要求。

#### 4.3.1 Memcache

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Memcache是一套分布式的高速缓存系统，对于大型的需要频繁访问数据库的网站访问速度提升效果十分显著，以提升网站的访问速度。通过在内存里维护一个统一的巨大的hash表，它能够用来存储各种格式的数据，包括图像、视频、文件以及数据库检索的结果等。简单来说就是将数据调用到内存中，然后从内存中读取，从而提高读取速度。Memcached是以守护线程方式运行于一个或多个服务器中，随时接收客户端的连接和操作。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于完全依赖内存，使Memcache的容量根据部署节点的内存而定，在32位系统中容量最大限定2G。由于在内存中维护一个Hash表结构来缓存数据，所以它的数据保存形式遵从K-V简单结构，key默认最大不能超过128个字 节，value默认大小是1M，不过可以针对每条数据设定过期策略。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Memcache操作也相对简单，针对Hash表常用的操作如：set设置、get读取、replace替换、delete删除和flush刷新等。目前只支持文本类型的存取，所以在面向对象中可以将需要存储的对象经过序列化处理并保存，读取之后可以通过反序列化还原。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Memcache采用LRU过期策略，不支持持久化，所以当内存断电时会发生数据丢失，且无备份功能。

```java
/* Java 调用Memcache */
public class MemcachedJava {
   public static void main(String[] args) {
   
      try{
         // 连接本地的 Memcached 服务
         MemcachedClient mcc = new MemcachedClient(new InetSocketAddress("127.0.0.1", 11211));
         // 存储数据
         Future future = mcc.set("key1", 900, "This is Value1");
         // 查看存储状态
         System.out.println("set status:" + future.get());
         // 缓存读取
         System.out.println("value in cache : " + mcc.get("key1"));
         // 新增数据
         mcc.add("key2", 900, "This is Value2");
         // 数据替换
         mcc.replace("key2", 900, "is");
         // 数据后向追加
         mcc.append("key2", 900, " Value2");
         // 数据前向追缴
         mcc.prepend("key2", 900, "This ");
         // 删除数据
         mcc.delete("key1");
         // 关闭连接
         mcc.shutdown();
      }catch(Exception ex){
         System.out.println( ex.getMessage() );
      }
   }
}
```



#### 4.3.2 Redis

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;相比于Memcache，Redis具有更多的功能扩展性，可以满足更复杂的场景，并且支持String、Hash、Set、List和sorted set类型，还支持数据的持久化、虚拟内存等。它可以用作数据库、缓存和消息中间件。redis会周期性的把更新的数据写入磁盘或者把修改操作写入追加的记录文件，并且在此基础上实现了master-slave(主从)同步。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis支持主从同步，数据可以从主服务器向任意数量的从服务器上同步，从服务器可以是关联其他从服务器的主服务器。由于完全实现了发布/订阅机制，使得从数据库在任何地方同步树时，可订阅一个频道并接收主服务器完整的消息发布记录。同步对读取操作的可扩展性和数据冗余很有帮助

> 发布/订阅机制：是一种消息通信模式,发布者(pub)发送消息到特定的频道( channel)，订阅者(sub)通过观察频道( channe)接收消息。在分布式环境中，Redis分为客户端和服务端，消息的发布和订阅都是客户端行为，服务端提供channel，如果没有订阅消息，客户端会进入订阅监听状态，一旦接收到订阅消息就会进行消息同步。
>
> 类似于，有一档天气预报的节目，节目主持人（channel）实时获得气象局（pub）发布的气象信息，并把消息告诉正在观看节目的观众（订阅者），观众会一直盯着节目看直到收到气象预报并更新大脑关于今天的气象信息。

Redis的虚拟内存技术VM提升了数据保存的界限，其实际原理是当数据量已经达到存储边界，会对数据进行冷热隔离，将热数据继续保存在内存中，而冷数据通过压缩手段保存到磁盘上，压缩后的数据仅为原数据的1/10，虽然冷数据的查询效率不及热数据，但考虑到本身查询频率低，并不会影响整体性能。

```java
public class RedisJava {
    public static void main(String[] args) {
        //连接本地的 Redis 服务
        Jedis jedis = new Jedis("localhost");
        //查看服务是否运行
        System.out.println("服务正在运行: "+jedis.ping());
       
        // redis 字符串
        jedis.set("key1", "This is key1");
        System.out.println(jedis.get("key1"));
        
        // redis list
        jedis.lpush("list", "val1");
        jedis.lpush("list", "val2");
        jedis.lpush("list", "val3");
        jedis.llen("list"); // 长度
        List<String> list = jedis.lrange("list", 0 ,2);
        
        // 排序
        SortingParams sortingParams = new SortingParams();
        sortingParams.alpha();
        sortingParams.limit(0, 3);
        jedis.sort(list, sortingParams)
        
        // keys
        Set<String> keys = jedis.keys("*"); 
        Iterator<String> it=keys.iterator() ;
        
        // 删除
        if (jedis.exists("key1"))
        	jedis.del("key1");
        
        // 过期策略
        jedis.persist("key1");
        jedis.ttl("key1");
    }
}
```



#### 4.3.3 Memcache和Redis的区别以及性能比较

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实际上，两者既存在竞争又存在互补，由于实现细节的不同触手会伸向对方触及不到的业务场景。

1. **内存空间**：MemCached可以修改最大内存，但终究首先于内存。Redis增加了VM的特性，突破了物理内存的限制，实现冷热分离。
2. **操作**：MemCached数据结构单一，仅用来缓存数据，面向对象保存需要用到序列化和反序列化手段；Redis支持更加丰富的数据类型，也可以在服务器端直接对数据进行丰富的操作,这样可以减少网络IO次数和数据体积。
3. **可靠性**：MemCache不支持数据持久化，断电或重启后数据消失。Redis支持数据持久化和数据恢复，允许单点故障，但是同时也会付出性能的代价。
4. **应用场景**：Memcache动态系统中减轻数据库负载，提升性能，适合多读少写标准缓存场景。 
    Redis适用于对读写效率要求都很高，数据处理业务复杂和对安全性要求较高的系统。
5. **性能**：性能上都很出色，具体到细节，由于Redis只使用单核，而Memcached可以使用多核，所以平均每一个核上Redis在存储小数据时比 
    Memcached性能更高。而在100k以上的数据中，Memcached性能要高于Redis。



### 4.4  JPA缓存策略

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;JPA是Java持久层接口，是官方发布的ORM标准，Hibernate是对JPA的全量实现框架支持全自动处理，移植性更好；Mybatis仅部分遵循JPA规则实现半自动处理，灵活性更高。我们再此不展开讨论两者孰优孰劣，仅从缓存层面来看框架级对持久层缓存的支持情况。

#### 4.4.1 Spring-JPA-Data(Hibernate)缓存策略

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring-JPA-Data是Spring框架对实现JPA接口的ORM框架的轻量级封装，默认使用Hibernate。Hibernate缓存包括两大类：一级缓存和二级缓存。一级缓存又被称为“Session的缓存”。Session缓存是内置的，不能被卸载，是事务范围的缓存，session级别缓存数据不共享；二级缓存又称为“SessionFactory的缓存”，由于SessionFactory对象的生命周期和应用程序的整个过程对应，因此Hibernate二级缓存是进程范围或者集群范围的缓存，是可以被不同Session所共享的，默认使用EhCache也可显示的替换为Memcache或其他缓存产品。

1. 一级缓存默认开启，仅存在与session周期内，缓存时间短，范围小，效果不明显。
2. 二级缓存默认不开启，需手动配置开启，是热拔插设计，不影响整体性能，可以显著提高效率，同样的将占用更多的内存空间。

#### 4.4.2 Mybatis缓存策略

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Mybatis同样采用一二级缓存策略，情况类似与Hibernate的使用。一级缓存称为SqlSession级缓存，与Hibernate的Session缓存一致，二级缓存属于SqlSessionFactory级别，类似于SessionFactory，不同的是，Mybatis二级缓存支持在单一对象映射中使用，比如针对特定的Mapper进行缓存，这就对选择业务场景使用更有帮助。



### 4.5 缓存击穿、穿透、雪崩、污染

{% asset_img 缓存过程.png 缓存过程%}

**缓存穿透**：缓存和数据库中都没有真实数据，此时大量访问该无效数据造成系统压力增大，如果攻击者使用缓存穿透持续攻击，将造成持久层崩溃。

> 解决方案
>
> 1. 对无效数据访问后可在缓存创建值为null的返回，并设定较短的过期时间，可以有效避免攻击。
> 2. 业务层添加有效性校验，拦截较容易识别的风险。



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
> 2. 可以设置热点数据永久不过期。



**缓存污染**：系统将不常用的数据从内存移到缓存，造成常用数据的失效，降低了缓存的利用率。缓存容量是弥足珍贵的，容量过大反而容易影响查询效率，所以在有效的空间内保证热点数据很重要。

> 解决策略
>
> 1. 设置合理的过期策略，FIFO、LRU、LFU等。
> 2. 业务层识别，避免大而全的数据添加进缓存中。