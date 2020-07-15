---
title: 使用Lombok
date: 2020-6-20
tags: [第三方工具, Lombok]
---
{% asset_img image1.jpg spring %}

# 使用Lombok
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Lombok是一款简化POJO对象创建，消除通用代码的第三方工具，通过简单的注解方式自动生成代码，配合IDE集成的插件功能可以有效提高开发效率。

```java
@ToString(exclude = {"sex"})
@EqualsAndHashCode
@AllArgsConstructor
@NoArgsConstructor
@RequiredArgsConstructor(staticName = "create")
@Accessors(chain = true)
public class Human {

    @Getter(AccessLevel.PACKAGE) @Setter(AccessLevel.PACKAGE)
    @EqualsAndHashCode.Exclude
    @NonNull
    private int id;

    @Getter @Setter
    @NonNull
    private String name;

    @Getter @Setter
    private int age;

    @Getter @Setter
    private boolean sex;

}

// 测试
public static void main(String[] args) {
    Human human = new Human();
    human.setName("123");
    System.out.println(human);

    Human human1 = new Human(1, "x", 1, true);
    System.out.println(human1);

    Human human2 = Human.create(2,"xxx");
    System.out.println(human2);

    Human human3 = new Human();
    human3.setId(3).setName("yyy");
    System.out.println(human3);
}

// output
// Human(id=0, name=123, age=0)
// Human(id=1, name=x, age=1)
// Human(id=2, name=xxx, age=0)
// Human(id=3, name=yyy, age=0)
```



**@Getter和@Setter**： 

1. 通过对类变量设置注解可以允许自动创建对应的get和set方法，boolean类型set方法为is开头；
2. 如果需要设置可见性，可以通过 AccessLevel枚举类型设置，如`@Setter(AccessLevel.PRIVATE)`;



**@ToString**:

1. 默认使用带参数的，以逗号分隔的，不打印继承类信息的toString方法。
2. 如果不希望打印某些字段可以屏蔽`@ToString(exclude = {"id","sex"})`，会重写toString()方法;
3. 如果希望打印父类中的信息，可以设置`@ToString(callSuper = true)`，会调用父类toString()方法;



**构造函数**：

1. @NoArgsConstructor，添加无参构造函数，如果类中存在final字段且没有初始化，则可以默认设置初始值。`@NoArgsConstructor(force = true)`;
2. @AllArgsConstructor，添加全部参数的构造函数，且不提供无参构造函数。
3. @RequiredArgsConstructor，可以添加@NonNull指定参数的构造函数，同时该注解支持静态工厂方法创建对象，只需要注解内设置方法名即可，`@RequiredArgsConstructor(staticName = "create")`;

```java
Human human2 = Human.create(2,"xxx");
System.out.println(human2);
```



**@EqualsAndHashCode**：

1. 支持重写equals()和hashCode()方法，默认情况下，静态变量和transient变量不会参与其中。
2. 可以指定排除某些字段`@EqualsAndHashCode(exclude = {"id"})`;
3. 默认不会比较父类对象，可以设置是否比较父类对象`@EqualsAndHashCode(callSuper = true)`;



**@NonNull**:

1. 用于指定成员变量时会在set方法时进行非空判断，如果入参为空则抛出NPE异常。
2. 可以用于创建指定参数的对象，参照@RequiredArgsConstructor。



**@Accessor**:

1. fluent 变量用于控制setter和getter方法名是否包含get和set字符，默认false；
2. chain 变量用于创建链式调用，默认false；
3. prefix 变量用于创建getter和setter时，是否删除指定前缀。

```java
@Accessors(fluent = false, chain = true, prefix = "hi")
public class Human {
    @Setter
    private int id;
    
    @Setter
    private int hiName;
}

// 测试
Human human = new Human();
human.setId(1).setName("xxx");
```



**@Value和@Data**:

1. @Data注解包含@Getter、@Setter、@ToString、@EqualsAndHashCode、@RequiredArgsConstrutor的全部含义，控制粒度过大，不推荐使用。可以通过将构造器设置为私有，通过该注解就可以创建一个静态工厂方法`@Data(staticConstructor = "valueOf")`;
2. @Value注解与@Data类似，只不过不提供@Setter方法。