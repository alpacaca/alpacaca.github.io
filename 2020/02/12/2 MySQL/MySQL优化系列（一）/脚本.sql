CREATE DATABASE `optdemo1` CHARACTER SET 'utf8';

USE `optdemo1`;

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

