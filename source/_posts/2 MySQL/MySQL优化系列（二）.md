---
title: MySQL优化系列（二）
date: 2020-2-22
tags: [mysql, MySQL优化, 数据结构]
---
{% asset_img image1.jpg MySQL %}

# MySQL优化系列（二）
<!--more-->

## 3 数据库级优化
### 3.1 索引数据结构

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;索引是DQL优化的核心，可以显著提高查询的效率，但值得注意的是凡事有利则有弊，数据检索性能的提高是依赖数据库内部维护的检索表，它是一个B+Tree的数据结构，本身就会占用空间且当对表做出DML操作时，需要同步维护该索引，所以DML的效率则会下降，效果可以类比线性表存储结构。建议对频繁进行数据查询的表创建索引，并选择合适的索引类型，同时以满足业务需求为目的创建，否则会适得其反。



<br />

#### 3.1.1 B-Tree

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B-Tree是数据库中使用最为常见的数据结构，由平衡二叉查找树演化而来，现在多使用的B+Tree结构由B-Tree演化而来，所以有必要先介绍B-Tree。

> B-Tree中的B是Balance而非Binary；"B-Tree"和"B+Tree"会被有些人称为”B减树“和”B加树“，这样称呼看似合人情但不合理，因为B-Tree创建之时不可能已经意识到B+Tree的存在，也就不存在名称对立，所以个人认为，“-”只是一个连接符，没有任何含义，应该称为“B树”和“B加树”。
>
> B-Tree并不是二叉树，而是多叉树。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;首先需要理解，为什么需要B-Tree，这就需要从非关系型数据库的存储来讲，我们在开发过程中通常将MVC分层中数据库DML操作称为“持久化”过程，其实是因为数据库中的数据都是保存在磁盘中的。系统从磁盘读取数据并保存到内存是以“磁盘块（block）”为基础单位，位于同一磁盘块的数据会被一次性加载进来，而不是按需加载。那么，B-Tree的意义就是如何以最优的方式找到数据所在的磁盘块加载需要的数据，减少io损耗。

> 众所周知，磁盘IO是系统的瓶颈之一，且无法大幅优化提升效率，那么减少IO次数就很关键。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;定义一组普通映射[key, data]，key为索引的键（数据不同则键值不同），data为索引对应的一行表数据。B-Tree数据结构定义如下：

1. 所有叶子节点都在同一层，且没有指向其他节点的指针。
2. 每个非末端节点包含n个关键字或引用，保存每个节点保存更多的信息。
3. 满足平衡二叉树的定义，即节点的索引值大于左子树索引值，小于右子树索引值，但可以有多个子节点。
4. 索引值必包含对应的映射数据信息。

{% asset_img B-Tree.png MySQL %}

> 题：以查找索引值51为例，经过的步骤如下：

1. 根节点磁盘块读取并存入内存中，48 < 51，所以指向指针P2的子节点。（1次磁盘IO，1次内存加载）
2. P3指向的磁盘块读取并存入内存，找到目标51并返回对应的行数据。（1次磁盘IO，1次内存加载）

> 题：以查找索引值15为例，经过的步骤如下：

1. 根节点磁盘块读取并存入内存中，13 < 15 < 48，所以指向指针P2的子节点。（1次磁盘IO，1次内存加载）
2. P2指向的磁盘块读取并存入内存，15 < 20，所以指向指针P1的子节点。（1次磁盘IO，1次内存加载）
3. P1指向的磁盘块读取并存入内存，找到目标15返回对应行数据。（1次磁盘IO，1次内存加载）

经过上述步骤查找，最终经过3次磁盘IO和3次内存加载，定位到索引15并读取的对应的行信息返回。所以在当前索引中最优结果是1次磁盘IO和1次内存加载，即根节点位置定位。最差结果是3次磁盘IO和3次内存加载，相比于平衡二叉树或红黑树等数据结构，由于节点保存的信息较多，所以树的高度偏扁平，这样减少了磁盘IO，从而提高了查找效率。



<br />

#### 3.1.2 B+Tree

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B-Tree虽然已经很适合作为非关系型数据库的索引模型，但它还存在一些弊端：**索引根节点是固定的，没必要每次查找都经过1次磁盘IO读取和加载；由于磁盘块容量有限，而节点保存数据会占用节点很大的空间，所以一个磁盘块能够保存的索引个数会减少，导致树高度可能增加；范围查找变得效率不高。**所以在此基础之上，B+Tree做到了如下优化:

1. 根节点常驻内存，减少1次IO损耗；
2. 所有非叶子节点只保存索引值或引用，不保存映射数据，扩增节点保存关键信息的能力；
3. 有两个全局指针，一个指向根节点，另一个指向索引值最小的节点（最左叶子节点）。
4. 所有叶子节点保存索引值和映射数据，且叶子节点由单链表关联，指针指向相邻的右兄弟节点，结合第3条信息，这就提供了查找的多样性，可以选择从根节点开始检索树，也可以从顺序链表头开始进行查询，因为有链表的存在，支持范围查询且效率比B-Tree更好。

{% asset_img B+Tree.png MySQL %}

> 题：以查找索引值41为例，经过的步骤如下（与B-Tree一致）：

1. 从内存加载根节点，找到 13 < 41 < 48，指向指针P2的节点。
2. 读取磁盘块，找到 20 < 41 < 42，指向指针P2的几点。
3. 读取磁盘块，找到目标并返回对应数据。

> 题：以查找索引值13为例，过程如下：

1. 内存加载根节点，找到目标13（<font color=red>此时从右指针查找</font>）。
2. 加载磁盘块，13 < 20，指向P1指针节点。
3. 加载磁盘块，找到目标并返回。

**注：为什么非叶子节点定位到目标值要从右侧指针查找，查找了大量网络资源都没有找到合适的答案，最终从维基百科和《高性能Mysql》一书中推测而来。欢迎各位交换意见。**

{% asset_img wiki.png MySQL %}

{% asset_img performance.jpg MySQL %}



<br />

#### 3.1.3 扩展：B*Tree

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B*Tree是B+Tree的优化，进一步要求，在非根非叶子节点各层中的节点之间互相产生指向相邻右兄弟

节点的指针。

{% asset_img BMulti-Tree.png MySQL %}



<br />

#### 3.1.4 聚簇索引、非聚簇索引和辅助索引

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;B+Tree在数据库中的实现方式即为聚簇索引，其含义是指在一张索引表中，既存在索引值同时存在映射数据；**在Innodb引擎中使用聚簇索引，在MyISAM引擎中就使用非聚簇索引**，其含义是指，在B+Tree结构中叶子节点索引值对应的并不是数据而是数据在数据页中的地址，通过地址就可以直接在内存中获得数据，数据页是管理磁盘块的最小单位；辅助索引是指，在索引表Index1中查找关键字key1时，需要先从索引表Index2中查找关键字key2对应的关键字key1。



<br />

### 3.2 索引的创建与修改

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在我们已经创建的四张表中，都设置了整型自增主键id，Mysql已经自动帮我们添加了主键索引（MySQL 5.7+版本），也就是说当我们使用id查询时是通过主键索引进行查询。索引按照创建方式可以分为：**一般索引、唯一索引、复合索引、主键索引和全文索引**。其中主键索引属于唯一索引范畴，全文索引已经在**2.6**章节中进行了介绍，是MyISAM引擎支持的文本类索引，在此不再深入讨论。



<br />

#### 3.2.1 一般索引

> 创建tb_course表时对课程名name添加索引

``` sql
#创建课程表，包括id，名称，是否必修课，学分
CREATE table `tb_course`(
	id int primary key auto_increment,
	name varchar(20),
	is_required boolean,
	credit int,
	INDEX course_name_index(name)
)ENGINE = InnoDB CHARACTER SET = utf8;
```

执行命令`SHOW INDEX FROM tb_course \G`查看当前表的所有索引：

```mysql
mysql> show index from tb_course \G
*************************** 1. row ***************************
        Table: tb_course
   Non_unique: 0
     Key_name: PRIMARY
 Seq_in_index: 1
  Column_name: id
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null:
   Index_type: BTREE
      Comment:
Index_comment:
*************************** 2. row ***************************
        Table: tb_course
   Non_unique: 1
     Key_name: course_name_index
 Seq_in_index: 1
  Column_name: name
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
      Comment:
Index_comment:
```

可以看到row1是系统自动添加的主键索引，row2是我们创建的自定义索引。

> 通过 CREATE 和 ALTER关键字创建索引

``` sql
CREATE INDEX course_name_index ON `tb_course`(name);

ALTER TABLE `tb_course` ADD INDEX course_name_index(name);
```

> 删除索引

```sql
DROP INDEX course_name_index ON `tb_course`;
```



<br />

#### 3.2.2 唯一索引

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;唯一索引与一般索引的不同之处在于，它所持有的字段必须是唯一的，如果是唯一复合索引，那么复合字段必须是唯一的，其他用法一直，只需要将`INDEX`替换为`UNIQE INDEX`。

> 创建tb_course表时对课程名name添加唯一索引

```sql
#创建课程表，包括id，名称，是否必修课，学分
CREATE table `tb_course`(
	id int primary key auto_increment,
	name varchar(20),
	is_required boolean,
	credit int,
	UNIQUE INDEX course_name_index(name)
)ENGINE = InnoDB CHARACTER SET = utf8;
```

> 通过 CREATE 和 ALTER关键字创建唯一索引

```sql
CREATE UNIQUE INDEX course_name_index ON `tb_course`(name);

ALTER TABLE `tb_course` ADD UNIQUE INDEX course_name_index(name);
```



<br />

#### 3.2.3 复合索引

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;复合索引语法与一般索引一致，只是持有多个字段。

> 创建tb_course表时对课程名、是否必修和学分添加复合索引

```sql
#创建课程表，包括id，名称，是否必修课，学分
CREATE table `tb_course`(
	id int primary key auto_increment,
	name varchar(20),
	is_required boolean,
	credit int,
	INDEX union_index(name, is_required, credit)
)ENGINE = InnoDB CHARACTER SET = utf8;
```

> 通过 CREATE 和 ALTER关键字创建复合索引

```sql
CREATE INDEX union_index ON `tb_course`(name, is_required, credit);

ALTER TABLE `tb_course` ADD INDEX union_index(name, is_required, credit);
```

> 通过命令SHOW INDEX FROM tb_course \G查看结果

```mysql
mysql> show index from tb_course \G
*************************** 1. row ***************************
        Table: tb_course
   Non_unique: 0
     Key_name: PRIMARY
 Seq_in_index: 1
  Column_name: id
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null:
   Index_type: BTREE
      Comment:
Index_comment:
*************************** 2. row ***************************
        Table: tb_course
   Non_unique: 1
     Key_name: union_index
 Seq_in_index: 1
  Column_name: name
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
*************************** 3. row ***************************
        Table: tb_course
   Non_unique: 1
     Key_name: union_index
 Seq_in_index: 2
  Column_name: is_required
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE

*************************** 4. row ***************************
        Table: tb_course
   Non_unique: 1
     Key_name: union_index
 Seq_in_index: 3
  Column_name: credit
    Collation: A
  Cardinality: 0
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
```

可以看到row 2.3.4信息中，索引名称相同，都是union_index，并且索引序列`Seq_in_index`分别是1,2,3，也就是说我们复合索引查找是有序列限制的（最左原则，后续章节介绍）。