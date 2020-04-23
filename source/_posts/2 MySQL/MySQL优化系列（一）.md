---
title: MySQL优化系列（一）
date: 2020-2-12
tags: [mysql, MySQL优化]
---
{% asset_img image1.jpg MySQL %}

# MySQL优化系列（一）
<!--more-->

## 0 总述
按照Java当前框架式的开发模式，我总结**单系统**Mysql优化主要分为三类：

1. 代码级优化。
2. 数据库级优化。
3. 框架级优化。


**代码级优化**主要包含：

1. 尽量使用联接查询代替子查询（嵌套查询）。
2. 避免使用关键字LIKE或正则表达式匹配，会导致全表扫描。
3. DELETE删除大量数据后，使用Optimize table tb_xxx释放残余空间。
4. 避免在where中使用函数或表达式。
5. 避免使用使索引失效的操作。
6. 避免使用select *，会导致全表查询。
7. 使用相对较高的性能分页，比如where id > 100 limit 20 性能优于limit 100, 20。
8. Join时使驱动表为小数据量表。



**数据库级优化**主要包含：

1. 建立索引，并使用explain调试接近最优查询。
2. 合理使用存储过程。
3. 选择适合业务特点的数据库引擎（事务、锁机制）。
4. 掌握使用慢查询日志。
5. mysql buffer和cache。
6. 物理资源使用分析（cpu使用率和io阻塞）。



**框架级优化**主要指多级缓存策略，其中包含：

1. 关系型数据库中，ORM框架支持的一二级缓存。
2. 非关系型数据库中，redis数据库缓存。



{% asset_img MySQL优化总结.png MySQL优化脑图 %}

<br />

## 1 准备

### 1.1 数据准备

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在展开研究Mysql数据库优化前，我们先创建一组数据，用于分析所有涉及的操作行为。四张数据表的数据字典如下：（主键id均为整型自增，非特别说明都使用varchar类型）

> `tb_course` : id，name（课程名），is_required（是否必修课 boolean），credit（学分 int）
>
> `tb_teacher` :  id，name（教师名），age（年龄），course_id（所授课程id）
>
> `tb_student` : id，name（学生名），age（年龄 int）
>
> `tb_student_course` :  id，student_id（学生id），course_id（课程id），is_pass（是否及格 boolean），score（得分 int）

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;创建数据库脚本代码如下：

```sql
CREATE DATABASE `optdemo` CHARACTER SET 'utf8';

USE `optdemo`;

#创建课程表，包括id，名称，是否必修课，学分
CREATE table `tb_course`(
	id int primary key auto_increment,
	name varchar(20),
	is_required boolean,
	credit int
)ENGINE = InnoDB CHARACTER SET = utf8;

#创建老师表，包括id，名称，年龄，教授课程
CREATE table `tb_teacher`(
	id int primary key auto_increment,
	name varchar(20),
	age int,
	course_id int
)ENGINE = InnoDB CHARACTER SET = utf8;

#创建学生表，包括id，名称，年龄，所学课程
CREATE table `tb_student`(
	id int primary key auto_increment,
	name varchar(20),
	age int
)ENGINE = InnoDB CHARACTER SET = utf8;

#创建学生--课程关系表，包括id，学生id，课程id，是否通过
CREATE table `tb_student_course`(
	id int primary key auto_increment,
	student_id int not null,
	course_id int not null,
	is_pass boolean,
	score int
)ENGINE = InnoDB CHARACTER SET = utf8;

#初始化表
INSERT INTO `tb_course` (name, is_required, credit) 
VALUES 
('C', true, 4), 
('JAVA', true, 4), 
('数据结构', true, 3), 
('操作系统', true, 4), 
('C#', false, 2), 
('Python', false, 3), 
('人工智能', true, 4), 
('TCP/IP', false, 2), 
('计算机网络', true, 3),
('Linux', false, 2);

INSERT INTO `tb_teacher` (name, age, course_id)
VALUES
('老张', 45, 1),
('老王', 46, 2),
('老李', 48, 3),
('老赵', 35, 4),
('老吴', 55, 5),
('老孙', 45, 6),
('老刘', 40, 7),
('老贾', 39, 8),
('老钱', 32, 9),
('老周', 36, 10);

INSERT INTO `tb_student` (name, age)
VALUES
('小张', 18),
('小王', 18),
('小李', 18),
('小赵', 18),
('小吴', 18),
('小孙', 18),
('小刘', 18),
('小贾', 18),
('小钱', 18),
('小周', 18);

INSERT INTO `tb_student_course` (student_id, course_id, is_pass, score)
VALUES
(1,1,true, 80), (1,2,true, 90), (1,3,true, 92), (1,4,true, 93), (1,7,true,87), (1,9,true, 89), (1,10,true, 78), 
(2,1,true, 99), (2,2,true, 98), (2,3,true, 100), (2,4,true,100), (2,7,true,95), (2,8,true,91), (2,9,false,55),
(3,1,true, 76), (3,2,true,68), (3,3,true,82), (3,5,true,77), (3,7,true,71), (3,9,false,59),
(4,1,true,100), (4,2,true,100), (4,3,true,100), (4,4,true,100), (4,7,true,100), (4,9,true,100),
(5,1,false, 42), (5,2,false,39), (5,3,false,33), (5,4,false,21), (5,5,true,60), (5,7,false,0), (5,9,false,58),
(6,1,false,82), (6,2,true,78), (6,3,true,78), (6,4,false,49), (6,6,true,63), (6,7,false,47), (6,9,true,82),
(7,1,true,98), (7,2,true,96), (7,3,true,92), (7,4,true,91), (7,5,true,96), (7,6,true,99), (7,7,true,93), (7,8,true,99), (7,9,true,94), (7,10,true,98),
(8,1,false,32), (8,2,false,33), (8,3,false,42), (8,4,false,43), (8,7,false,52), (8,9,false,53),
(9,1,false,36), (9,2,false,39), (9,3,false,56), (9,4,false,55), (9,7,false,55), (9,9,false,51),
(10,1,true,86), (10,2,true,88), (10,3,true,92), (10,4,true,100), (10,5,true,100), (10,6,true,100), (10,7,false,100), (10,8,true,100), (10,9,true,100), (10,10,true,100);

```



<br />

### 1.2 Mysql逻辑分层结构

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;首先确定一个概念，通常开发中操作的是Mysql Client客户端，与Client相连并且处理数据和存储数据的称为Mysql Server或者Database Manager System（DBMS），Client职责就是输入并发送给Server处理，所以这里我们只讨论Server的逻辑分层结构。

{% asset_img 架构图.png Mysql架构图 %}

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从上图大体可以看出来，按逻辑共分为四层，概括一下包含：连接层、服务层、数据驱动层（引擎层）和数据层。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;① **连接层**被设计为连接池形式，主要负责与Client的通信，同时提供授权和安全等策略；

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;② **服务层**是Mysql Server的核心结构，主要包括：管理服务、SQL接口、SQL解析器、SQL优化器和缓存，具体介绍请看下一段。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;③ **数据驱动层（引擎层）**是由Mysql提供的插件式数据引擎套件，按照业务实际需要选择合适的引擎，将会很大程度上提高算力。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;④ **数据层**主要是物理层次的数据及相关信息的存储，例如慢查询日志等。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在服务层中，管理服务主要负责备份、恢复、数据迁移、集群等操作；SQL接口主要负责最熟悉的DML、DDL、存储过程、视图和触发器等处理；SQL解析器主要负责语法解析；SQL优化器主要负责重写*系统判定*不够优化的语句，也就是说，当我们通过Client提交一个SQL之后，优化器可能会对我们的SQL等效重写并继续向下执行，重写后的语句是Server认为足够优化的语句。SQL缓存将在之后章节具体介绍。

> 由于SQL优化器的存在，我们写的SQL并不一定是Server执行的SQL。



<br />

### 1.3 DQL执行顺序与SQL优化器

> DQL : Data Query Language 数据查询语言，特指Select及相关的(group by etc.)操作统称。
>
> DML : Data Manipulation Language 数据操作语言，包含INSERT、DELETE、UPDATE。
>
> DDL : Data Defination Language 数据定义语言，包含CREATE、 DROP等。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在数据库DQL中，存在一条线性的关键字匹配和处理流程，这里所说的关键字就是与数据库操作有关的系统关键字。首先看下列关键字序列：

```sql
SELECT DISTINCT
    < select_list >
FROM
    < left_table > 
< join_type > JOIN < right_table > 
ON < join_condition >
WHERE
    < where_condition >
GROUP BY
    < group_by_list >
HAVING
    < having_condition >
ORDER BY
    < order_by_condition >
LIMIT < limit_number >
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这是一条日常开发中涉及较多关键字的SQL，也是SQL解析器认为合法的表示流程，但实际上，SQL解析器解析之后是按照如下顺序执行：

```sql
FROM <left_table>
ON <join_condition>
<join_type> JOIN <right_table>
WHERE <where_condition>
GROUP BY <group_by_list>
HAVING <having_condition>
SELECT 
DISTINCT <select_list>
ORDER BY <order_by_condition>
LIMIT <limit_number>
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;掌握Mysql执行过程很重要，因为在后续优化过程中，经常需要确定驱动表以及多表查询时的执行顺序影响效率问题。

> 简化表示：FROM...ON...JOIN...WHERE...GROUP BY... HAVING...SELECT...DISTINCT...ORDER BY...LIMIT
>
> 简单来说，就是按顺序找到表，再从表中抽数据，再组织数据



<br />

## 2 代码级优化

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;代码级优化是指，针对手写或者ORM框架生成的原生SQL语句进行优化，优化目的是产生运行效率更高的执行语句。多数情况下，我们针对DQL进行优化。



<br />

### 2.1 使用联接代替子查询

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;子查询是指，使用SELECT查询出目标结果集，然后将该结果集当作其他查询的过滤条件使用。换句话说就是一个SELECT查询中的WHERE条件嵌套另一个或多个SELECT语句，这种写法不仅将多个逻辑联系起来更符合自然逻辑，而且避免了执行中的死锁和事务安全问题，但是，在执行过程中，Mysql会对子查询创建临时表，这就增加了IO消耗。

> 例：查询选修了Python课程的学生信息。

```sql
SELECT * FROM `tb_student`
WHERE id IN ( 
    SELECT student_id FROM `tb_student_course`
	WHERE course_id IN ( 
        SELECT id FROM `tb_course`
		WHERE name = 'Python'));
```

> <font color=red>声明：</font>为了方便，使用SELECT *写法，实际业务处理中应使用具体字段SELECT id, name, age写法。

上述例子中，使用了三层SELECT语句组成的完整查询，逻辑清晰但实际运行效率并不高，下面改成JOIN写法。

```sql
SELECT t1.* 
FROM `tb_student` t1 JOIN `tb_student_course` t2 
ON t1.id = t2.student_id JOIN `tb_course` t3
ON t2.course_id = t3.id
WHERE t3.name = 'Python';
```

或者

```sql
SELECT t1.* 
FROM `tb_student` t1, `tb_student_course` t2, `tb_course` t3 
WHERE t1.id = t2.student_id AND t2.course_id = t3.id AND t3.name = 'Python';
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在排除SQL优化器和缓存条件（重复执行，效率会提高）时，从执行时间来看，后两者效率明显比前者效率高。



<br />

### 2.2 删除操作

#### 2.2.1 DELETE、DROP和TRUNCATE的区别

1. DELETE属于DML，执行操作时，每次从目标表中删除一行数据，并且删除行为作为日志保存以便进行”恢复“操作；而DROP和TRUNCATE属于DDL，其操作不能回滚。
2. DELETE时会执行相关的触发器，并且执行之后需要显示的commit才能完成删除动作<sup>[1]</sup>；而DROP和TRUNCATE会隐式commit，且不会执行触发器。
3. DROP删除表中所有数据，并释放表空间；TRUNCATE删除表中所有数据，重置高水位（high watermark）<sup>[2]</sup>；DELETE逐行删除，高水位保持不变。

> [1] : 在Mysql中，默认DML开启了自动提交，所以执行DML之后无需commit，但并不代表它是隐式执行，可以通过`SHOW VARIABLES LIKE 'autocommit'`查看。

> [2] : 举个例子，例如表中id主键自增且当前id=10，当DELETE 全表之后再新增，id为11；而TRUNCATE和DROP之后再新增，id=1。



<br />

#### 2.2.2 DELETE大数据量优化

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DELETE删除大数据量后，不仅产生了许多日志空间，且所删除的空间并未被释放，此时需要使用OPTIMIZE TABLE [数据库]来释放。

```sql
DELETE FROM `tb_student_course`;

OPTIMIZE TABLE `tb_student_course`;
```



<br />

### 2.3 避免使用SELECT *

1. 使用SELECT *会查询全表字段作为结果集，当我们只需要部分而不是全部字段作为结果集时，就会造成资源浪费，不仅降低了查询效率，还增加了网络IO使用率；当多人维护表时，如果表字段发生变化（增加或者删除）就会造成预期外的结果，或者需要额外的后台代码进行过滤，不利于维护。

2. 安全性考虑，如果发生SQL注入风险，有可能被攻击者创建联表条件，从而更多信息被暴露。

3. SELECT 目标列正好是索引时，会更快的从内存（B+Tree）中读取数据并返回而不产生本地IO。

4. 【本条转自】：https://blog.csdn.net/u013240038/article/details/90731874

    连接查询时，* 无法进入缓冲池查询。
    每次驱动表加载一条数据到内存中，然后被驱动表所有的数据都需要往内存中加载一遍进行比较。效率很低，所以mysql中可以指定一个缓冲池的大小，缓冲池大的话可以同时加载多条驱动表的数据进行比较，放的数据条数越多io操作就越少，性能也就越好。所以，如果此时使用select * 放一些无用的列，只会白白的占用缓冲空间。浪费本可以提高性能的机会。




<br />

### 2.4 分页优化

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;数据库层级的分页优化，实际上就是针对LIMIT关键字的优化，Mysql支持的LIMIT关键字系统中可以用作分页处理，表达式：LIMIT offset,rows 或 LIMIT rows。比如`LIMIT 123456,50`，从123456行开始查询50条数据；`LIMIT 50`将查询结果取前50条数据。LIMIT虽然使用方便但在大数据量时就会出现性能问题，随着offset增大，性能急剧下降，究其原因是因为`LIMIT 123456,50`会先扫描123456+50=123506条数据，然后返回50条，额外扫描的123456并不是我们需要的，事实上这样的设计显得多余，当数据量级增加之后，性能必然骤降。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;优化方式一：从实际情况来看，受影响的似乎只有`LIMIT offset, rows`形式，而`LIMIT rows`并不影响性能，实际上后者只扫描rows行数据，所以我们可以进行如下替换：

```sql
SELECT * FROM table LIMIT 123456,50;
#LIMIT扫描123506条数据
#转换后
SELECT * FROM table WHERE id >= 123456 LIMIT 50;
#LIMIT只扫描50条数据
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;优化方式二：使用覆盖索引，在后续介绍索引时将深入介绍，在此简单提一下：覆盖索引是指，查询列正好全部具有索引，则结果直接从B+Tree中获取而不用回表操作。比如`SELECT col1 FROM tb_test LIMIT 123456,50；`，正好col1具有索引，那么执行该语句的时候会直接从col1索引对应的数据结构中获得结果，而不用回表到tb_test中再次查询，减少了磁盘IO。

```sql
ALTER TABLE `tb_test` ADD INDEX col1_index(col1);
SELECT col1 FROM tb_test LIMIT 123456, 50;
```

> 注：创建表并添加主键之后，会自动创建主键索引 Primary Key Index。



<br />

### 2.5 JOIN时使驱动表为小数据量表

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在前文中我们已经提到使用JOIN代替子查询可以明显提高效率，但JOIN本身也有需要更进一步的优化。首先介绍一下JOIN的原理：将驱动表的查询结果作为“输入”，当作条件逐条的在被驱动表内进行过滤，最终返回过滤后的数据，这种JOIN的方式被称作NEST LOOP。

```sql
SELECT t1.* 
FROM tabel1 t1 LEFT JOIN table2 t2 
ON t1.condition = t2.condition
JOIN table3 t3
ON t1.condition = t3.condition AND t2.condition = t3.condition
WHERE ....
ORDER BY t2.id DESC;
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这是一个相对复杂的例子，其中用到了LEFT JOIN和JOIN，解析一下过程：将table1当作驱动表查询并返回结果result1，将result1当作被驱动表t2的“输入”，并将result1中的数据逐条取出在table2中匹配，并将最终的结果返回result2，将table1和table2联合查询后的结果result2当作table3的”输入“，并逐条匹配并返回最终结果result3，排序后当作最终的结果返回。所以在使用多表JOIN时，明确表的数据条的多少，有助于我们确定使用小表作为驱动表，从而减少循环次数，达到优化的目的。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;庆幸的是，在不显式地指定驱动表时，SQL优化器帮助我们将最小的表作为驱动表来执行，所谓显式指定是指LEFT JOIN时左侧表为驱动表，RIGHT JOIN时右侧表为驱动表，而JOIN属于隐式，SQL优化器会自行决定小表为驱动表。

> 思考：上述SQL还存在严重影响性能的地方，可以先做思考，将在后续索引章节介绍。



<br />

### 2.6 避免使用LIKE和正则匹配 

> 题：找出年龄是5或5的倍数的所有老师信息。

使用LIKE关键字查找如下：

```sql
SELECT * FROM tb_teacher
WHERE age LIKE "%5" OR age LIKE "%0";
```

使用正则表达式如下：

```sql
SELECT * FROM tb_teacher
WHERE age REGEXP ".5|0";
```

两者效果等价，结果如下：

| id   | name | age  | course_id |
| ---- | ---- | ---- | --------- |
| 1    | 老张 | 55   | 1         |
| 4    | 老赵 | 45   | 4         |
| 5    | 老吴 | 35   | 5         |
| 6    | 老孙 | 45   | 6         |
| 7    | 老刘 | 40   | 7         |

可以看到LIKE和正则在进行内容过滤检索时很灵活，也很方便，但是 这两者查询都是基于全表的查询，大数据量时查询效率很低，所以给出一下两种解决办法。

1. 当使用MyISAM引擎时，建议使用全文索引FULLTEXT，因为只有MyISAM引擎是支撑该特殊索引方式的，所以可以在创建表的时候使用`FULLTEXT(字段)`来定义，如下：

    ```sql
    CREATE table `tb_student`(
    	id int primary key auto_increment,
    	name varchar(20),
    	age int,
        description text,
        FULLTEXT(description)
    )ENGINE = Myisam CHARACTER SET = utf8;
    ```

    Mysql会创建索引表维护该索引列，查询时使用如下方式：

    ```sql
    SELECT * FROM tb_student WHERE MATCH(description) AGAINST('关键字');
    ```

2. 当业务中不得不实现LIKE模糊匹配时，最好在匹配字符中不以占位符开始`LIKE '关键字%'`，这样可以使查询字段的索引生效，相反则会索引失败进行全表查询；如果不得不以占位符开始，那么可以使用覆盖索引来提高效率。