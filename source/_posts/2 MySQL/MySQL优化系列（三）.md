---
title: MySQL优化系列（三）
date: 2020-2-24
tags: [mysql, MySQL优化]
---
{% asset_img image1.jpg MySQL %}



# MySQL优化系列（三）
<!--more-->

### 3.2 EXPLAIN 执行计划

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;执行计划的查看是进行SQL调优的重要步骤，也是收集可调优选项的信息集中地，Mysql中通过关键EXPLAIN来查看SELECT的查询效率。我们已经知道在逻辑分层中，服务层存在SQL优化器，它可以对我们的SQL进行优化并最终在引擎中执行，EXLAIN可以模拟SQL优化器执行结果。

#### 3.2.1 使用和介绍

```sql
EXPLAIN SELECT * FROM `tb_course`\G
```

该语句将模拟优化器执行，并将执行信息打印在控制台，如下：

```mysql
mysql> EXPLAIN SELECT * FROM tb_course \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: index
possible_keys: NULL
          key: union_index
      key_len: 70
          ref: NULL
         rows: 14
     filtered: 100.00
        Extra: Using index
```

<font color=red>[id]：</font> SELECT执行语句的编号，是一组整型数值。

① 当Explain某一复杂语句时，可能包含多条子查询，那么查询顺序按照编号由大到小执行；

② 当查询编号一致时，按照从上到下的顺序执行。

例1：

```mysql
 mysql> EXPLAIN SELECT * FROM tb_student WHERE id IN (SELECT student_id FROM tb_student_course WHERE course_id=(SELECT id FROM tb_course WHERE name='JAVA') ) \G
 
 *************************** 1. row ***************************
           id: 1
  select_type: PRIMARY
        table: <subquery2>
   partitions: NULL
         type: ALL
possible_keys: NULL
          key: NULL
      key_len: NULL
          ref: NULL
         rows: NULL
     filtered: 100.00
        Extra: NULL
*************************** 2. row ***************************
           id: 1
  select_type: PRIMARY
        table: tb_student
   partitions: NULL
         type: eq_ref
possible_keys: PRIMARY
          key: PRIMARY
      key_len: 4
          ref: <subquery2>.student_id
         rows: 1
     filtered: 100.00
        Extra: NULL
*************************** 3. row ***************************
           id: 2
  select_type: MATERIALIZED
        table: tb_student_course
   partitions: NULL
         type: ALL
possible_keys: NULL
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 1
     filtered: 100.00
        Extra: Using where
*************************** 4. row ***************************
           id: 3
  select_type: SUBQUERY
        table: tb_course
   partitions: NULL
         type: ref
possible_keys: union_index
          key: union_index
      key_len: 63
          ref: const
         rows: 5
     filtered: 100.00
        Extra: Using index
4 rows in set, 1 warning (0.04 sec)
```

该用例中查询序列按照` 3 -> 2 -> 1 -> 1`执行，首先查询`SELECT id FROM tb_course WHERE name='JAVA'`接着将子查询结果作为条件执行`SELECT student_id FROM tb_student_course WHERE course_id=subquery`，SQL优化器将最后主查询`SELECT * FROM tb_student WHERE id IN (subquery)` 与上一步子查询进行联接，先查询`student_id`，再查询最终结果。



例2：

```mysql
#查询选修了Java的学生课程关联表
mysql> EXPLAIN SELECT * FROM tb_student_course WHERE course_id IN (SELECT id FROM tb_course WHERE name LIKE 'JAVA%') \G

*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_student_course
   partitions: NULL
         type: ALL
possible_keys: NULL
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 1
     filtered: 100.00
        Extra: NULL
*************************** 2. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: eq_ref
possible_keys: PRIMARY,union_index
          key: PRIMARY
      key_len: 4
          ref: optdemo.tb_student_course.course_id
         rows: 1
     filtered: 35.71
        Extra: Using where
```

该例子中应当属于子查询嵌套类型且id顺序不一致，只是SQL优化器进行了优化，将嵌套查询优化为联接，所以编号一致，执行顺序从上到下。

<font color=red>[select_type]：</font>表示查询类型：Simple简单查询，Primary外侧主查询，Subquery内测子查询，Derived驱动查询表示当前语句位于FROM后，Materialized被物化的子查询。

<font color=red>[table]：</font>当前查询所在的目标表。

<font color=red>[partitions]：</font>查询目标是分区表的位置，如果查询目标在其他分区的表中将显示出来。在早先Mysql版本中，需要使用Exlain Extends才会显示该选项。

<font color=red>[type]：</font>访问类型，用于判断当前查询优化类别，是单表优化的重要指标，type效率指标由优到差依次为：

**`system > const > eq_ref > ref > range > index > all`**

- **system : ** 查询结果只有一条数据，且扫描表中数据也只有一条，WHERE后使用主键索引查询。

- **const : ** 查询结果只有一条数据，且扫面表中有多条数据，WHERE后使用主键索引查询，system是const的特殊情况。

- **eq_ref : ** 查询结果为多条数据，使用唯一索引或主键索引查询。

- **ref : ** 查询结果为多条数据，使用普通索引或复合索引查询。

- **range : ** 查询结果为多条数据，使用索引查询且是范围索引，如使用`>`、`<`、`BETWEEN`、`AND`、`OR`、`IN`等

- **index : ** 查询结果为多条数据，使用索引查询，但对索引表进行全表扫描。

- **all : ** 查询结果为多条数据，未使用索引，对全表数据扫描。

一般来说，在实际业务中，system和const情况几乎不可能达到，而index和all的效率过低是主要的被优化目标，而期望的优化目标则为eq_ref、ref，range情况特殊它属于范围内的索引表扫描，实际优化应考虑索引扫描范围。

<font color=red>[possible_keys]：</font> SQL优化器执行前预估的索引类型。

<font color=red>[key]：</font> 实际执行时用到的索引类型。

<font color=red>[key_len]：</font> 实际使用的索引长度，用于确认用到的索引。

<font color=red>[ref]：</font> 联接查询时的联接条件

<font color=red>[rows]：</font> 返回结果集时，所查询的总行数。

<font color=red>[filtered]：</font> 表示返回数据在server层过滤后，剩下多少满足查询的记录数量的百分比，同partition，在5.7版本以前需要使用explain extended查询。

<font color=red>[Extra]：</font> 表示查询时额外的说明信息，该字段与type一样，同样时需要优化时特别关注的，常遇到的类型包括：using filesort、using temporary、using index、using where、distinct等，特别需要关注前两项，它们出现是性能损耗过大的表现。

- **using filesort : ** 常见于使用order by 排序，由于索引查询后排序并未使用索引字段或索引字段失效，导致排序时将在内存中的“排序空间”进行，排序空间通过**sort_buffer_size**设置，会额外产生空间和时间的浪费。

- **using temporary : ** 常见于group by或order by操作，当查询结果进行分组时会在内存中额外使用“临时表”空间存储和聚合，额外产生空间和时间的浪费，多见于order by或group by字段并非多表查询结果字段。

- **using index : ** 表示当前查询使用了索引查询，无需回表查询，性能提升。

- **using where : ** 返回的记录并不是所有的都满足查询条件，需要在server层进行过滤，即回表查询，属于“后置过滤”，在版本5.6之后出现了**using index condition**，它的含义是先在索引表中查询复合索引过滤条件的数据，再将这些数据使用where其他条件进行过滤，与using where相比，将索引过滤提前到索引表内，所以where条件优先设置索引过滤（SQL优化器是否会自动优化还待确认）。

- **distinct : ** 表示数据查询后使用了distinct筛查，将查询结果进行二次全部扫描，排除重复项。

#### 3.2.2 最左前缀原则

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在复合索引的使用过程中经常提到”**最左前缀原则**“，它的意思是说，当创建一个复合索引`tb_index(col1, col2, col3)`，使用索引必须按照严格的定义顺序，比如`SELECT * FROM tb WHERE col=x and col2=xx and col3=xxx`，这样联合索引才能达到最高效率。如果执行如下破坏顺序索引的例子将不能完全发挥索引功能或丧失索引功能：`SELECT * FROM tb WHERE col1=x and col3=xxx`（跳过中间索引col2，只有col1生效，col3无法使用索引），`SELECT * FROM tb WHERE col2=xx and col3=xxx`(跳过col1，索引全部失效)。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了探讨最左前缀原则的原理，重新回到索引的数据结构，我们已经讨论过无论是MyISAM还是InnoDB引擎都是用B+Tree数据结构进行索引表的保存，不妨以科学疑问的形式提出两种数据结构的假设：

1. 一个列代表一个b+tree结构，多个列则分表对应多个b+tree，比如上例提到的复合索引，col1、col2、col3在物理模型上分别对应三个b+tree文件，当执行**SELECT * FROM tb WHERE col1=x and col2=xx and col3=xxx**时，首先从col1索引表中定位，定位到的data域保存指向col2索引的指针从而在col2对应的索引表中定位，col3同理，最终在col3的叶子节点data域中找到目标结果。
2. 在物理模型上只有一个索引文件，即一个b+tree保存联合索引，并在key域中以严格的定义顺序保存多列索引字段按次序依次定位，从而最终获得目标结果。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;先确认第二条为正确结果，那么我们来讨论第一条为什么不是，为什么数据库大多都采用B+Tree作为结构模型而非红黑树之类，主要原因在于索引本身就是一张容量较大的表结构，使用内存是性能损耗和系统稳定性都受点影响的一件事，那么只能考虑作为文件保存在物理磁盘上，而物理磁盘的IO效率又过低容易影响系统整体的吞吐量，所以衡量索引最重要的标准就是在查询中减少磁盘IO的次数，显然第一条假设严重违背了这样的标准，因为如果复合索引的多列分别对应多张索引的话，那么磁盘上的文件也会一一对应，当我们执行覆盖索引的SQL语句时，就代表经过多次磁盘IO，效率很可能反而降低了。



#### 3.2.3 避免索引失效

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在索引列上做任何操作(计算、 函数、自动\手动类型转换)，会导致索引失效而转向全表扫描，究其原因，主要是破坏（不满足）B+Tree索引表的查询条件，以下常见场景需要注意（由于MYSQL优化器在不同版本之间表现不同，所以结果可能有出入）：

1. <font color=red>模糊查询LIKE后接匹配符 **%** 或 **_**时，只能出现在最末位置。</font>

    当前tb_course表中数据，以及索引情况如下，索引只有主键索引和联合索引union_index(name, is_required, credit)。

```mysql
mysql> SELECT * FROM tb_course ;
+----+-----------------+-------------+--------+
| id | name            | is_required | credit |
+----+-----------------+-------------+--------+
|  1 | C               |           1 |      4 |
|  5 | C#              |           0 |      2 |
| 11 | JAVA            |           0 |      0 |
| 12 | JAVA            |           1 |      1 |
| 13 | JAVA            |           1 |      2 |
| 14 | JAVA            |           1 |      3 |
|  2 | JAVA            |           1 |      4 |
| 10 | Linux           |           0 |      2 |
|  6 | Python          |           0 |      3 |
|  8 | TCP/IP          |           0 |      2 |
|  7 | 人工智能         |           1 |      4 |
|  4 | 操作系统         |           1 |      4 |
|  3 | 数据结构         |           1 |      3 |
|  9 | 计算机网络       |           1 |      3 |
+----+-----------------+-------------+--------+

mysql> SHOW INDEX IN tb_course\G
*************************** 1. row ***************************
        Table: tb_course
   Non_unique: 0
     Key_name: PRIMARY
 Seq_in_index: 1
  Column_name: id
    Collation: A
  Cardinality: 14
     Sub_part: NULL
       Packed: NULL
         Null:
   Index_type: BTREE
*************************** 2. row ***************************
        Table: tb_course
   Non_unique: 1
     Key_name: union_index
 Seq_in_index: 1
  Column_name: name
    Collation: A
  Cardinality: 10
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
  Cardinality: 11
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
  Cardinality: 14
     Sub_part: NULL
       Packed: NULL
         Null: YES
   Index_type: BTREE
```

```mysql
#MySQL 5.7
mysql> EXPLAIN SELECT * FROM tb_course WHERE name LIKE '%AVA%'\G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: index
possible_keys: NULL
          key: union_index
      key_len: 70
          ref: NULL
         rows: 14
     filtered: 11.11
        Extra: Using where; Using index
1 row in set, 1 warning (0.00 sec)
```

从结果可以看到，最终的执行计划显示使用了联合索引union_index，这是因为在当前测试使用的MYSQL版本为5.7，SQL优化器对`%AVA%`进行了优化处理使得可以进行索引查询，但在MYSQL5.6之前版本中将显示无法使用索引，执行计划显示使用全局查询，如下：

```mysql
#MySQL 5.6
mysql> EXPLAIN SELECT * FROM tb_course WHERE name LIKE '%AVA%'\G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: ALL
possible_keys: NULL
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 10
     filtered: 11.11
        Extra: Using where
```

建议：尽量使用全文索引，如果必须使用模糊查询，建议匹配条件不以%或_开头。



<font color=red>2.  OR的前后字段必须都为索引字段，否则索引失效</font>

当OR前后字段只有一个是索引时，那么全部不使用索引，相反当所有字段是索引时才会使用索引。

```mysql
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE id=2 OR name='老张'\G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: ALL
possible_keys: PRIMARY
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 10
     filtered: 19.00
        Extra: Using where
1 row in set, 1 warning (0.00 sec)
```

id是主键索引，而name字段无索引，所以结果显示`possible_keys: PRIMARY`可能使用到主键索引，实际并未使用索引`key: NULL`。



<font color=red>3. 联合索引需要满足最左原则，否则索引部分失效或全部失效</font>

见 **3.2.2**



<font color=red>4. 堤防隐式转换破坏索引查询</font>

当字段为varchar类型索引时，如果使用整型类型当作条件查询，则会破坏索引规则，使失效。

```mysql
# 测试新增索引
mysql> ALTER TABLE tb_teacher ADD INDEX name_index(name);
Query OK, 0 rows affected (0.07 sec)
Records: 0  Duplicates: 0  Warnings: 0

# 正常
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE name='123' \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: ref
possible_keys: name_index
          key: name_index
      key_len: 63
          ref: const
         rows: 1
     filtered: 100.00
        Extra: NULL
1 row in set, 1 warning (0.00 sec)

# 失效
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE name=123 \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: ALL
possible_keys: name_index
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 11
     filtered: 10.00
        Extra: Using where
1 row in set, 3 warnings (0.00 sec)
```

建议： 日常开发中在书写SQL时需要细心注意索引字段类型，此类问题一般比较隐蔽。



<font color=red>5. 不等表示( <>, !=) 和 空判断(is null, is not null) 使索引失效</font>

因为不等和为空都不会进入索引表，所以即使针对索引列判断也无法生效，将进行全表扫描。

```mysql
# 不等操作
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE name <> '123' \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: ALL
possible_keys: name_index
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 11
     filtered: 100.00
        Extra: Using where
   
# 为空判断   
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE name is not null \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: ALL
possible_keys: name_index
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 11
     filtered: 100.00
        Extra: Using where
```

注意，possible_keys计划使用name_index索引，实际并未使用索引。

当针对整型类型进行不等操作时，被优化器优化处理：

```mysql
# 主键索引
mysql> EXPLAIN SELECT * FROM tb_teacher WHERE id <> 10 \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_teacher
   partitions: NULL
         type: range
possible_keys: PRIMARY
          key: PRIMARY
      key_len: 4
          ref: NULL
         rows: 10
     filtered: 100.00
        Extra: Using where
        
# 联合索引
mysql> explain select * from tb_course where credit <> 0 \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: index
possible_keys: NULL
          key: union_index
      key_len: 70
          ref: NULL
         rows: 14
     filtered: 90.00
        Extra: Using where; Using index
```



<font color=red>6. 计算、函数表达式使索引失效</font>

当对索引字段进行函数或计算则*有可能*使其失效，之所以说有可能同样时因为不同版本中SQL优化器表现不同所致。

```mysql
mysql> EXPLAIN SELECT * FROM tb_course WHERE credit*2 > 2 \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: index
possible_keys: NULL
          key: union_index
      key_len: 70
          ref: NULL
         rows: 14
     filtered: 100.00
        Extra: Using where; Using index
```

可以看到，此处使用了索引查询，也就表示在当前测试版本中优化器进行了优化操作，在MYSQL 5.6之前索引无效。



<font color=red>7. 当全表扫描速度更快时，索引失效</font>

当优化器认为全表扫描速度优于索引查找时，使索引失效，这种场景往往牵扯到创建索引时涉及的块的读取成本问题。



#### 3.2.4 单表优化实战

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了演示单表优化过程，以tb_course为例，首先删除已经存在的索引` drop index union_index on tb_course;`，<font color=red>再次申明，测试使用的MYSQL当前版本为5.8，不同版本SQL优化器执行计划不一定相同</font>。

> 查询学分不为0的必修课的名称。

```mysql
mysql> EXPLAIN SELECT name FROM tb_course WHERE is_required=1 AND credit <>0 ORDER BY credit DESC \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: ALL
possible_keys: NULL
          key: NULL
      key_len: NULL
          ref: NULL
         rows: 14
     filtered: 9.00
        Extra: Using where; Using filesort
```

当前type为ALL表示未使用索引，最差全表扫描查询。

> 1. 是否可以将name, is_required, credit设置为联合索引提高效率？

```my
mysql> ALTER TABLE tb_course ADD INDEX test_index1(name,is_required,credit);
Query OK, 0 rows affected (0.05 sec)
Records: 0  Duplicates: 0  Warnings: 0

mysql> EXPLAIN SELECT name FROM tb_course WHERE is_required=1 AND credit <>0 ORDER BY credit DESC \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: index
possible_keys: NULL
          key: test_index1
      key_len: 70
          ref: NULL
         rows: 14
     filtered: 9.00
        Extra: Using where; Using index; Using filesort
```

在当前版本测试中显示type升级为index，Extra新增 Using index项，效率确实有少许提升（在MySQL5.6版本中可能显示任然无法使用索引或索引失效），但没有达到我们优化的目标级别(range以上)，此时我们仔细分析一下：在SQL执行顺序中（**1.3**章节），执行顺序应该为 FROM > WHERE > SELECT > ORDER BY，所以当前创建的索引test_index1(name,is_required,credit)并没有按照执行顺序执行，换句话说，当前SQL使用的索引顺序是乱序的。

> 2. 按照执行顺序创建联合索引是否可行？

```mysql
mysql> drop index test_index1 ON tb_course;
Query OK, 0 rows affected (0.03 sec)
Records: 0  Duplicates: 0  Warnings: 0

mysql> ALTER TABLE tb_course ADD INDEX test_index2(is_required, credit, name);
Query OK, 0 rows affected (0.04 sec)
Records: 0  Duplicates: 0  Warnings: 0

mysql> EXPLAIN SELECT name FROM tb_course WHERE is_required=1 AND credit <>0 ORDER BY credit DESC \G
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: tb_course
   partitions: NULL
         type: range
possible_keys: test_index2
          key: test_index2
      key_len: 7
          ref: NULL
         rows: 10
     filtered: 100.00
        Extra: Using where; Using index
```

很明显可以看到type效率达到了range级别，并且减少了Using filesort这个特别消耗性能的操作。



### 3.3  ORDER BY排序原理与优化

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在Mysql版本中ORDER BY的排序算法经过了两代演进，最初使用**双路排序算法：将排序字段和对应的行指针从磁盘中读出并在内存中进行排序，遍历该排序列表并从磁盘读取原表匹配返回查询结果。**可以看到双路排序算法经过了两次磁盘IO，这在效率上很受影响，属于空间优于时间策略。对应的优化版本则是**单路排序算法：将排序字段及其对应的所有查询项一次从磁盘读取获得并在内存中进行排序，排序后的结果即是输出结果**，在该算法下将磁盘IO降到最低，对时间效率进行了提升，但同时需要注意多字段读出到内存中，如果数据量巨大则容易导致OOM，如果在系统内存范围内但同样数据量较大则容易产生回表操作，反而不如双路排序算法有优势。在内存中进行排序操作依赖Mysql在内存中创建的缓存区buffer大小，如果数据量超出buffer就会导致创建临时表或回表操作甚至发生OOM，Mysql默认buffer为1024字节，所以预估数据量大小很重要或者使用explain执行计划查看低效率风险，将buffer设置在预估范围边界。

```mysql
mysql> show variables like "max_length_for_sort_data";
+--------------------------+-------+
| Variable_name            | Value |
+--------------------------+-------+
| max_length_for_sort_data | 1024  |
+--------------------------+-------+

mysql> set global max_length_for_sort_data=2048;
Query OK, 0 rows affected (0.01 sec)

mysql> show variables like "max_length_for_sort_data";
+--------------------------+-------+
| Variable_name            | Value |
+--------------------------+-------+
| max_length_for_sort_data | 2048  |
+--------------------------+-------+
```

以此类比，GROUP BY也是类似问题，只不过优先排序后分组，所以优化策略相同。

### 3.4 慢查询日志

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在复杂业务场景下，Mysql经常会因为某个复杂查询SQL影响整体性能，甚至出现假死状态，主要原因是因为数据业务量大致使该查询语句耗费太多时间，Mysql提供慢查询日志支持在线网环境下定位具体慢查询语句，默认情况下慢查询处于关闭状态，可以使用指令slow_query_log查看（配置文件开启可以永久生效），通过指定日志文件（默认文件为slow-query-log-file）和设定慢查询时间阈值来截取SQL。

```mysql
# 查询慢查询开关是否开启
mysql> show variables like "slow_query_log" ;
+----------------+-------+
| Variable_name  | Value |
+----------------+-------+
| slow_query_log | OFF   |
+----------------+-------+
# 开启慢查询
mysql> set global slow_query_log=1;
Query OK, 0 rows affected (0.02 sec)

mysql> show variables like "slow_query_log";
+----------------+-------+
| Variable_name  | Value |
+----------------+-------+
| slow_query_log | ON    |
+----------------+-------+

# 查询时间阈值
mysql> show variables like 'long_query_time';
+-----------------+-----------+
| Variable_name   | Value     |
+-----------------+-----------+
| long_query_time | 10.000000 |
+-----------------+-----------+

# 设置时间阈值
mysql> set global long_query_time=5;

mysql> show variables like 'long_query_time';
+-----------------+-----------+
| Variable_name   | Value     |
+-----------------+-----------+
| long_query_time | 5.000000 |
+-----------------+-----------+
```

配置my.ini或my.cnf配置慢查询（需重启服务）

```txt
# 配置文件
[mysqld]
slow_query_log =1
long_query_time=5
slow_query_log_file=D:\\software\\work\\mysql-5.7.23-winx64\\slowquery.log
```

```mysql
mysql> show variables like "slow_query_log";
+----------------+-------+
| Variable_name  | Value |
+----------------+-------+
| slow_query_log | ON    |
+----------------+-------+

mysql> show variables like "long_query_time";
+-----------------+----------+
| Variable_name   | Value    |
+-----------------+----------+
| long_query_time | 5.000000 |
+-----------------+----------+

mysql> show variables like "slow_query_log_file";
+---------------------+----------------------------------------------------+
| Variable_name       | Value                                              |
+---------------------+----------------------------------------------------+
| slow_query_log_file | D:\software\work\mysql-5.7.23-winx64\slowquery.log |
+---------------------+----------------------------------------------------+
```

通过sleep函数设置睡眠时间来测试：

```mysql
mysql> select sleep(6);
```

手动查看日志

```txt
MySQL, Version: 5.7.23-log (MySQL Community Server (GPL)). started with:
TCP Port: 3306, Named Pipe: (null)
Time                 Id Command    Argument
# User@Host: root[root] @ localhost [::1]  Id:     3
# Query_time: 5.999740  Lock_time: 0.000000 Rows_sent: 1  Rows_examined: 0
SET timestamp=1586104027;
select sleep(6);

```

使用mysql提供的慢查询命令mysqldumpslow查看

```mysql
# 按照平均时长排序并输出前十项
C:\Users\zhy>mysqldumpslow.pl -s at -t 10 D:\software\work\mysql-5.7.23-winx64\slowquery.log
# mysqldumpslow.pl需要安装perl环境才能使用
```

### 3.5 使用Profiling

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;除了使用Explain执行计划查看单个SQL的执行效率外，还可以通过Profiling来查看当前会话中多条SQL的执行性能，主要指标是CPU、BLOCK IO、CONTEXT SWITCH、MEMORY、SWAPS等。

> CPU：显示CPU使用相关开销
>
> BLOCK IO：阻塞IO相关开销
>
> CONTEXT SWITCH：上下文切换相关开销
>
> MEMORY：内存相关开销
>
> SWAPS：交换之间的开销

默认情况下是关闭的，可以开启并显示最近执行的SQL

```mysql
# 查看开关和历史记录数
mysql> show variables like 'profiling%';
+------------------------+-------+
| Variable_name          | Value |
+------------------------+-------+
| profiling              | OFF   |
| profiling_history_size | 15    |
+------------------------+-------+

# 设置开关和记录数
mysql> set global profiling=1;

mysql> set global profiling_history_size=20;

mysql> show variables like 'profiling%';
+------------------------+-------+
| Variable_name          | Value |
+------------------------+-------+
| profiling              | ON    |
| profiling_history_size | 20    |
+------------------------+-------+

# 查看最近的执行SQL
mysql> show profiles;
+----------+------------+----------------------------------+
| Query_ID | Duration   | Query                            |
+----------+------------+----------------------------------+
|        1 | 0.00040300 | select @@version_comment limit 1 |
|        2 | 0.00438400 | show variables like 'profiling%' |
|        3 | 0.00018800 | show version()                   |
|        4 | 0.00028400 | select version()                 |
|        5 | 0.00044975 | show engines                     |
|        6 | 0.00034125 | SELECT DATABASE()                |
|        7 | 0.00255175 | select * from tb_teacher         |
+----------+------------+----------------------------------+

# 查看Query_ID为7的所有性能信息
*************************** 1. row ***************************
             Status: starting
           Duration: 0.000211
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: NULL
        Source_file: NULL
        Source_line: NULL
*************************** 2. row ***************************
             Status: checking permissions
           Duration: 0.000016
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: check_access
        Source_file: sql_authorization.cc
        Source_line: 810
*************************** 3. row ***************************
             Status: Opening tables
           Duration: 0.001980
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: open_tables
        Source_file: sql_base.cc
        Source_line: 5685
*************************** 4. row ***************************
             Status: init
           Duration: 0.000026
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: handle_query
        Source_file: sql_select.cc
        Source_line: 121
*************************** 5. row ***************************
             Status: System lock
           Duration: 0.000012
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: mysql_lock_tables
        Source_file: lock.cc
        Source_line: 323
*************************** 6. row ***************************
             Status: optimizing
           Duration: 0.000004
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: JOIN::optimize
        Source_file: sql_optimizer.cc
        Source_line: 151
*************************** 7. row ***************************
             Status: statistics
           Duration: 0.000016
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: JOIN::optimize
        Source_file: sql_optimizer.cc
        Source_line: 367
*************************** 8. row ***************************
             Status: preparing
           Duration: 0.000017
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: JOIN::optimize
        Source_file: sql_optimizer.cc
        Source_line: 475
*************************** 9. row ***************************
             Status: executing
           Duration: 0.000003
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: JOIN::exec
        Source_file: sql_executor.cc
        Source_line: 119
*************************** 10. row ***************************
             Status: Sending data
           Duration: 0.000078
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: JOIN::exec
        Source_file: sql_executor.cc
        Source_line: 195
*************************** 11. row ***************************
             Status: end
           Duration: 0.000042
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: handle_query
        Source_file: sql_select.cc
        Source_line: 199
*************************** 12. row ***************************
             Status: query end
           Duration: 0.000010
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: mysql_execute_command
        Source_file: sql_parse.cc
        Source_line: 4937
*************************** 13. row ***************************
             Status: closing tables
           Duration: 0.000009
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: mysql_execute_command
        Source_file: sql_parse.cc
        Source_line: 4989
*************************** 14. row ***************************
             Status: freeing items
           Duration: 0.000107
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: mysql_parse
        Source_file: sql_parse.cc
        Source_line: 5594
*************************** 15. row ***************************
             Status: cleaning up
           Duration: 0.000022
           CPU_user: 0.000000
         CPU_system: 0.000000
  Context_voluntary: NULL
Context_involuntary: NULL
       Block_ops_in: NULL
      Block_ops_out: NULL
      Messages_sent: NULL
  Messages_received: NULL
  Page_faults_major: NULL
  Page_faults_minor: NULL
              Swaps: NULL
    Source_function: dispatch_command
        Source_file: sql_parse.cc
        Source_line: 1924
```

```mysql
# 使用具体的性能分类，比如cpu和block io
mysql> show profile cpu,block io for query 7 \G
*************************** 1. row ***************************
       Status: starting
     Duration: 0.000211
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 2. row ***************************
       Status: checking permissions
     Duration: 0.000016
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 3. row ***************************
       Status: Opening tables
     Duration: 0.001980
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 4. row ***************************
       Status: init
     Duration: 0.000026
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 5. row ***************************
       Status: System lock
     Duration: 0.000012
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 6. row ***************************
       Status: optimizing
     Duration: 0.000004
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 7. row ***************************
       Status: statistics
     Duration: 0.000016
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 8. row ***************************
       Status: preparing
     Duration: 0.000017
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 9. row ***************************
       Status: executing
     Duration: 0.000003
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 10. row ***************************
       Status: Sending data
     Duration: 0.000078
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 11. row ***************************
       Status: end
     Duration: 0.000042
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 12. row ***************************
       Status: query end
     Duration: 0.000010
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 13. row ***************************
       Status: closing tables
     Duration: 0.000009
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 14. row ***************************
       Status: freeing items
     Duration: 0.000107
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
*************************** 15. row ***************************
       Status: cleaning up
     Duration: 0.000022
     CPU_user: 0.000000
   CPU_system: 0.000000
 Block_ops_in: NULL
Block_ops_out: NULL
```

应重点关注以下几个情况：

1. converting HEAP to MyISAM ：查询结果太大，内存转磁盘。

2. Creating tmp table :创建了临时表，性能损耗严重。

3. Copying to tmp table on disk：把内存中的临时表复制到磁盘，性能损耗严重

4. locked ：被加锁。

    