---
title: Spring及源码——IOC容器
date: 2020-6-15
tags: [Spring]
---
{% asset_img image1.jpg spring %}

# Spring及源码——IOC容器
<!--more-->



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring作为Java Web开发的首选全栈式框架，了解其作用机制和源码不仅利于日常开发熟练使用，还能从最优秀的开源框架中学习编码风格和设计风格。由于Spring涵盖内容甚广，将分章节介绍从基础Spring后台开发、Spring Boot、Spring Cloud等顺序记录。一句话夸Spring：**Spring是轻量级的开源框架，以IOC和AOP为核心功能，支持完备的企业级技术，拥有强大的三方整合能力。**

> 特别说明：作为Java世界最熟悉的框架，该系列不会经常从基础概念和如何使用详细介绍，有时可能一语带过，有时甚至都不会去讲，注重实现逻辑和源码是重点。



## 1 IOC容器

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring能够一统轻量级WEB开发领域，IOC是最重要也是最核心的部分，正是由于IOC的存在，使Spring可以在创建对象Bean的过程中进行自由的排列组合，创造更多的奇迹成为了可能。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;IOC（Inversion Of Control）：其中突出两个重点**控制**和**反转**，对象之间的耦合关系由Spring托管负责，而实际对象不用关心关联对象如何创建，只需要关注使用即可。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DI（Dependency Injection）：依赖注入，此概念由业界泰斗Matin Fowler提出，在早期它是为了更加直观的解释IOC的理念，随后逐渐演变为与IOC相同概念的词汇。



> 虽然DI诠释了IOC的核心理念，但在当代开发语境中两者并不等价，DI依然保持对象之间耦合关系的创建形式含义，而IOC不仅包含DI，还包含Bean生命周期、代理、资源装载等概念。



### 1.1 DI注入方式

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;依赖注入方式包含：**setter方法、构造器、工厂方法** 三种。**注解**方式是实现DI依赖注入的有效方式并不能当作依赖类型。

**以构造器注入为主，setter注入为辅**。



> 以对象Human注入演示，其中POJO用到了lombok，如果不清楚可以参照标签“第三方工具”查找使用方式。



创建Human类，提供无参构造器、全参数构造器和指定参数构造器，成员变量都实现getter和setter

```java
@ToString
@AllArgsConstructor
@NoArgsConstructor
public class Human {
    @Getter @Setter
    private int id;

    @Getter @Setter
    private String name;

    @Getter @Setter
    private int age;

    @Getter @Setter
    private boolean sex;

    public Human(int id, String name) {
        this.name = name;
        this.id = id;
    }

    public Human(String name, int age) {
        this.name = name;
        this.age = age;
    }

}
```



#### 1.1.1 配置方式注入

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xmlns:p="http://www.springframework.org/schema/p"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd
        http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context-4.0.xsd">

    <!-- 1.通过setter实现参数注入，要求对象类提供无参构造器 -->
    <bean id="human1" class="me.zhy.model.Human"
        p:id="1"
        p:name="xxx"
        p:age="10"
        p:sex="true"/>

    <!-- 2.采用参数名实现构造器注入，要求对象类提供全参构造器 -->
    <bean id="human2" class="me.zhy.model.Human">
        <constructor-arg name="id" value="2"/>
        <constructor-arg name="name" value="yyy"/>
        <constructor-arg name="age" value="20"/>
        <constructor-arg name="sex" value="true"/>
    </bean>

    <!-- 3.采用索引实现构造器注入，要求对象类提供全参构造器 -->
    <bean id="human3" class="me.zhy.model.Human">
        <constructor-arg index="0" value="3"/>
        <constructor-arg index="1" value="zzz"/>
        <constructor-arg index="2" value="30"/>
        <constructor-arg index="3" value="false"/>
    </bean>

    <!-- 4.额外的两个构造器由于参数类型相同，为了区分，采用联合索引和参数名方式注入-->
    <bean id="human4" class="me.zhy.model.Human">
        <constructor-arg index="0" name="name" value="www"/>
        <constructor-arg index="1" name="age" value="40"/>
    </bean>
</beans>
```

```java
// 测试
public static void main(String[] args) {
    ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");
    Human human1 = (Human) context.getBean("human1");
    System.out.println(human1);

    Human human2 = (Human) context.getBean("human2");
    System.out.println(human2);

    Human human3 = (Human) context.getBean("human3");
    System.out.println(human3);

    Human human4 = (Human) context.getBean("human4");
    System.out.println(human4);
}

// output:
// Human(id=1, name=xxx, age=10, sex=true)
// Human(id=2, name=yyy, age=20, sex=true)
// Human(id=3, name=zzz, age=30, sex=false)
// Human(id=0, name=www, age=40, sex=false)
```



**工厂方法和静态工厂方法**

创建工厂类

```java
public class HumanFactory {

    // 无参工厂方法
    public Human create1() {
        return new Human();
    }

    // 全参工厂方法
    public Human create2(int id, String name, int age, boolean sex) {
        return new Human(id, name, age, sex);
    }

    // 静态工厂方法，部分参数
    public static Human staticCreate(int id, String name) {
        return new Human(id, name);
    }

}
```



配置实现工厂方法注入

```xml
<!-- 创建工厂类 -->
<bean id="factory" class="me.zhy.model.HumanFactory" />
<!-- 1. 无参工厂方法 -->
<bean id="human1" factory-bean="factory" factory-method="create1" />
<!-- 2. 全参工厂方法 -->
<bean id="human2" factory-bean="factory" factory-method="create2">
    <constructor-arg name="id" value="1"/>
    <constructor-arg name="name" value="xxx"/>
    <constructor-arg name="age" value="10"/>
    <constructor-arg name="sex" value="true"/>
</bean>
<!-- 3. 静态工厂方法 -->
<bean id="human3" class="me.zhy.model.HumanFactory" factory-method="staticCreate">
    <constructor-arg name="id" value="2"/>
    <constructor-arg name="name" value="yyy"/>
    <constructor-arg name="age" value="20"/>
    <constructor-arg name="sex" value="false"/>
</bean>
```



```java
// 测试
ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");
Human human1 = (Human) context.getBean("human1");
System.out.println(human1);

Human human2 = (Human) context.getBean("human2");
System.out.println(human2);

Human human3 = (Human) context.getBean("human3");
System.out.println(human3);

// output:
// Human(id=0, name=null, age=0, sex=false)
// Human(id=1, name=xxx, age=10, sex=true)
// Human(id=2, name=yyy, age=0, sex=false)
```



#### 1.1.2 注解方式注入

配置文件设置注解扫描

```xml
<context:component-scan base-package="me.zhy.model" />
```



创建对象并通过注解实现注入

```java
@Data
@Component // 标记为一般对象
public class Department {
    private int id;
    private String name;
}

//

@Data
@Component
public class Location {
    private String name;
}

//

@Component("staff")
@ToString
public class Staff {
    @Getter @Setter
    private int id;
    @Getter
    private Department dept;
    @Getter
    private Location location;

    // 通过Autowired将标记为Component的类通过set方法注入
    @Autowired 
    public void setDept(Department dept) {
        this.dept = dept;
    }

    @Autowired
    public void setLocation(Location location) {
        this.location = location;
    }
}
```



通过构造器注入

```java
@Component("staff")
@ToString
public class Staff {
    @Getter @Setter
    private int id;
    @Getter
    private Department dept;
    @Getter
    private Location location;

    @Autowired
    public Staff(Department dept, Location location) {
        this.dept = dept;
        this.location = location;
    }
}
```

测试

```java
ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");
Staff staff = (Staff) context.getBean("staff");
System.out.println(staff);

// output:
// Staff(id=0, dept=Department(id=0, name=null), location=Location(name=null))
```



#### 1.1.3 依赖注入注解的区别

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在依赖注入时有多种注解可以选择，按照来源可以划分为如下：

Spring注解：

1. @Autowired，表示以类型注入，如果需要设置为以名字注入需要配合使用@Qualifier(value = "xxx")使用，这两者都是Spring提供。

```java
@Component("staff")
@ToString
public class Staff {
    @Getter @Setter
    private int id;

    @Getter @Setter
    @Autowired
    @Qualifier(value = "department")
    private Department dept;

    @Getter
    @Autowired
    @Qualifier(value = "location")
    private Location location;
}
```

这里的 department 和 location 是@Componenent标记 Department 类和 Location 类时的默认名称。



2. @Inject功能等同于@Autowired，@Named等同于@Qualifier，区别在于，这两者都是由JDK提供。
3. @Resource默认使用名称匹配，也可以指定由类型匹配，由JDK提供。

```java
// 默认使用名称匹配
@Resource(name = "department")
private Department dept;

// 指定类型匹配
@Resource(type = Department.class)
private Department dept;
```

4. @Dao表示数据控制层对象，@Service表示服务层对象，@Controller表示控制层对象，@RestController表示Rest风格的控制层对象。



#### 1.1.4 内部类注入

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于内部类在编译为字节码文件后通常表示为`OuterClass$InnerClass` ，即由外部类名和内部类名组成，所以在注入内部类时class应保持一致。

```java
class OuterClass {
    private InnerClass inner;
    
    public setInner(InnerClass inner) {
        this.inner = inner;
    }
    
    public class InnerClass {}
}
```

注入内部类

```xml
<bean id="outerClass" class="xxx.xxx.OuterClass">
	<property name="inner">
    	<bean class="xxx.xxx.OuterClass$InnerClass" />
    </property>
</bean>
```



#### 1.1.5 循环依赖问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在实际开发中可能会碰到循环依赖的问题，所谓循环依赖是指：**当多个类互相引用其他类作为自身成员变量，在构造对象时就会产生循环依赖。**



{% asset_img dependency.png spring %}



依赖注入时，按照注入方式的不同Spring采取了不同解决策略：

**构造器注入**：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过构造器注入依赖对象时，由于注入对象尚未创建完成，所以在创建对象时会报错：`Requested bean is currently in creation: Is there an unresolvable circular reference?`

```java
@Component("classA")
public class ClassA {
    private ClassB classB;

    @Autowired
    public ClassA (ClassB classB) {
        this.classB = classB;
    }
}

@Component("classB")
public class ClassB {
    private ClassC classC;

    @Autowired
    public ClassB (ClassC classC) {
        this.classC = classC;
    }
}

@Component("classC")
public class ClassC {
    private ClassA classA;

    @Autowired
    public ClassC (ClassA classA) {
        this.classA = classA;
    }
}

// 测试
ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");
context.getBean("classA");

// 异常信息
// Error creating bean with name 'classA': Requested bean is currently in creation: Is there an unresolvable circular reference?
```



通过构造器注入源码可以查看处理过程。

```java
// spring 源码
public class ConstructorResolver {
    
    public BeanWrapper autowireConstructor(String beanName, RootBeanDefinition mbd, @Nullable Constructor<?>[] chosenCtors, @Nullable Object[] explicitArgs) {
       ...
           
       // 创建构造器入参对象
       argsHolder = this.createArgumentArray(beanName, mbd, resolvedValues, bw, paramTypes, paramNames, this.getUserDeclaredConstructor(candidate), autowiring, candidates.length == 1); 
        
       ...
    }
    
    private ConstructorResolver.ArgumentsHolder createArgumentArray(String beanName, RootBeanDefinition mbd, @Nullable ConstructorArgumentValues resolvedValues, BeanWrapper bw, Class<?>[] paramTypes, @Nullable String[] paramNames, Executable executable, boolean autowiring, boolean fallback) throws UnsatisfiedDependencyException {
        ...
        try {
            // 执行注入参数创建时抛出异常
            convertedValue = this.resolveAutowiredArgument(methodParam, beanName, autowiredBeanNames, (TypeConverter)converter, fallback);
            args.rawArguments[paramIndex] = convertedValue;
            args.arguments[paramIndex] = convertedValue;
            args.preparedArguments[paramIndex] = autowiredArgumentMarker;
            args.resolveNecessary = true;
        } catch (BeansException var24) {
            throw new UnsatisfiedDependencyException(mbd.getResourceDescription(), beanName, new InjectionPoint(methodParam), var24);
        }     
}
```



**Setter注入（Scope=prototype）**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Setter注入在针对单例对象和原型对象时存在处理差异，在原型模式下循环依赖创建对象依然抛出与构造器注入一样的异常信息`Error creating bean with name 'classA': Requested bean is currently in creation: Is there an unresolvable circular reference?`，由此可见，在多实例模式下，spring无法自主判断并创建依赖对象。

```java
@Component("classA")
@Scope("prototype")
public class ClassA {
    private ClassB classB;

    @Autowired
    public void setClassB(ClassB classB) {
        this.classB = classB;
    }
}

@Component("classB")
@Scope("prototype")
public class ClassB {
    private ClassC classC;

    @Autowired
    public void setClassC(ClassC classC) {
        this.classC = classC;
    }
}

@Component("classC")
@Scope("prototype")
public class ClassC {
    private ClassA classA;

    @Autowired
    public void setClassA(ClassA classA) {
        this.classA = classA;
    }
}
// 获取classA对象时抛出异常
// `Error creating bean with name 'classA': Requested bean is currently in creation: Is there an unresolvable circular reference?`
```





**Setter注入（Scope=singleton）**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在Spring注入策略中，默认使用单例对象，由于单例对象始终保持唯一性，所以可以将单例对象存入内存中，这是Spring解决循环依赖的前提之一；同时Setter注入本身是通过空参构造器创建实例对象后在调用setter方法设置属性，利用这一特性是解决循环依赖的另一个前提。

```java
@Component("classA")
public class ClassA {
    private ClassB classB;

    @Autowired
    public void setClassB(ClassB classB) {
        this.classB = classB;
    }
}

@Component("classB")
public class ClassB {
    private ClassC classC;

    @Autowired
    public void setClassC(ClassC classC) {
        this.classC = classC;
    }
}

@Component("classC")
public class ClassC {
    private ClassA classA;

    @Autowired
    public void setClassA(ClassA classA) {
        this.classA = classA;
    }
}

// 测试
ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");
ClassA classA = (ClassA) context.getBean("classA");
System.out.println(classA);

// output
// me.zhy.model.ClassA@1787bc24
```



可以看到，在单例模式下循环依赖注入被spring解决了，前面已经提到，spring首先通过构造器创建实例对象，并将实例对象存入**可对外暴露的缓存中**，该缓存称作 *earlySingletonObjects* ，用于保存通过构造器创建但仍未setter赋值的对象，因此在发生循环依赖时，先通过缓存获得未完全赋值的对象并注入，解决循环依赖后再调用setter赋值。

```java
// spring源码
public class DefaultSingletonBeanRegistry {
    // 缓存单例对象
    private final Map<String, Object> singletonObjects = new ConcurrentHashMap(256);
    // 单例工厂对象
    private final Map<String, ObjectFactory<?>> singletonFactories = new HashMap(16);
    // 缓存未完全创建的对象，当对象完全创建后，会删除
    private final Map<String, Object> earlySingletonObjects = new HashMap(16);
    
    ...
    
    protected Object getSingleton(String beanName, boolean allowEarlyReference) {
        Object singletonObject = this.singletonObjects.get(beanName);
        if (singletonObject == null && this.isSingletonCurrentlyInCreation(beanName)) {
            synchronized(this.singletonObjects) {
                singletonObject = this.earlySingletonObjects.get(beanName);
                if (singletonObject == null && allowEarlyReference) {
                    ObjectFactory<?> singletonFactory = (ObjectFactory)this.singletonFactories.get(beanName);
                    if (singletonFactory != null) {
                        // 通过单例工厂创建单例对象
                        singletonObject = singletonFactory.getObject();
                        // 将创建但未setter的对象存入
                        this.earlySingletonObjects.put(beanName, singletonObject);
                        this.singletonFactories.remove(beanName);
                    }
                }
            }
        }

        return singletonObject;
    }
}
```



### 1.2 Bean的生命周期

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; IOC容器可以创建singleton单例对象和prototype多实例对象，对于多实例对象Bean，IOC负责创建之后则完全交给客户端程序；而单例对象Bean，IOC不仅负责创建，还负责单例对象在内存中的缓存已经整个生命周期，在客户端程序调用时通过缓存给予。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring装配Bean的过程中在关键步骤通过接口实现，就好像现代前端单页框架（如AngularJS2+ 框架等）在页面渲染过程中提供了 **生命周期钩子** ，通过获取这些钩子可以加入我们扩展的功能，达到定制Bean的效果。



{% asset_img bean.png lifecycle%}



Spring装载Bean过程描述：

1. 实例化 Bean。

2. 依赖注入完成 Bean 中所有属性值的赋值。

3. BeanNameAware 接口， 调用 setBeanName() 方法传入当前 Bean 的 id 。（一般不做修改）

4. BeanFactoryAware 接口，调用 setBeanFactory() 方法传入当前工厂实例的引用。（一般不做修改）

5. ApplicationContextAware 接口，调用 setApplicationContext() 方法传入当前 ApplicationContext 实例的引用。（一般不做修改）

6. BeanPostProcessor接口 称为 **后处理器** ，通过调用postProcessBeforeInitialzation() 方法对 Bean 进行加工操作，此处非常重要，Spring 的 AOP、动态代理等功能 就是利用它实现的。

   > BeanPostProcessor 独立于Bean，通过类似附加插件的形式注册到IOC中，并通过反射为IOC扫描识别，当Spring创建任何Bean时都会产生作用，所以它的影响是 **全局** 的。

7. InitializingBean 接口，调用 afterPropertiesSet() 方法。

8. 配置文件中通过 init-method 属性指定了初始化方法，则调用该初始化方法。

9. BeanPostProcessor接口的postProcessAfterInitializatio()方法，IOC容器再次对Bean进行加工处理。

   > 区别于step 6，通过方法名就可以见名知意，分别是before和after，即在之前和之后进行加工处理。

10. 如果Bean 的作用范围为 scope="singleton"，则将该 Bean 放入 Spring IoC 的缓存池中，将触发 Spring 对该 Bean 的生命周期管理； 如果Bean 的作用范围为 scope="prototype"，则将该 Bean 交给调用者，调用者管理该 Bean 的生命周期，Spring 不再管理该 Bean。
11. 如果 Bean 实现了 DisposableBean 接口，则 Spring 会调用 destory() 方法将 Spring 中的 Bean 销毁；如果在配置文件中通过 destory-method 属性指定了 Bean 的销毁方法，则 Spring 将调用该方法对 Bean 进行销毁。



> 通过代码举例来验证Spring装配Bean的过程：首先需要自定义BeanPostProcessor对象并聚合到容器中，再创建Bean中依次实现BeanNameAware 、BeanFactoryAware 、ApplicationContextAware 、InitializingBean 和 DisposableBean 接口。



1. 首先自定义一个后处理器，实现 postProcessBeforeInitialization() 方法和 postProcessAfterInitialization()方法，分别只针对Human类型的Bean做特殊化处理。

```java
// 将自定义后处理器加入IOC容器会自动生效
@Component
public class MyBeanPostProcessor implements BeanPostProcessor {

    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        if ("human".equals(beanName)) {
            Human human = (Human) bean;
            human.setName("zhangsan");
            System.out.println("=> MyBeanPostProcessor.postProcessBeforeInitialization(): change name zhangsan");
            return human;
        }
        return bean;
    }

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        if ("human".equals(beanName)) {
            Human human = (Human) bean;
            human.setSex(false);
            System.out.println("=> MyBeanPostProcessor.postProcessAfterInitialization(): change sex female");
            return human;
        }
        return bean;
    }
}
```



2. 接着定义类，实现生命周期钩子接口并打印。

```java
// 自定义类，实现生命周期钩子接口，并假如IOC容器中
@Component("human")
@Data
public class Human implements BeanNameAware, BeanFactoryAware,
        ApplicationContextAware, InitializingBean, DisposableBean {
    private int id;
    private String name;
    private boolean sex;

    private BeanFactory beanFactory;
    private String beanName;
    private ApplicationContext applicationContext;

    // BeanFactoryAware接口
    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        System.out.println("=> BeanFactory.setBeanFactory()");
        this.beanFactory = beanFactory;
    }

    // BeanNameAware接口
    @Override
    public void setBeanName(String s) {
        System.out.println("=> BeanNameAware.setBeanName()");
        this.beanName = s;
    }

    // DisposableBean接口
    @Override
    public void destroy() throws Exception {
        System.out.println("=> DisposableBean.destroy()");
    }

    // InitializingBean接口
    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("=> InitializingBean.afterPropertiesSet()");
    }

    // ApplicationContextAware接口
    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        System.out.println("=> ApplicationContextAware.setApplicationContext()");
        this.applicationContext = applicationContext;
    }
}
```



3. 通过IOC容器调用，查看Bean的创建过程。

```java
// 测试， 伪代码
ClassPathXmlApplicationContext context =
    new ClassPathXmlApplicationContext("applicationContext.xml");
Human human = (Human) context.getBean("human"); // 创建过程
context.destroy(); // 销毁容器即可调用DisposableBean接口
System.out.println(human);

// output
// => BeanNameAware.setBeanName()
// => BeanFactory.setBeanFactory()
// => ApplicationContextAware.setApplicationContext()
// => MyBeanPostProcessor.postProcessBeforeInitialization(): change name zhangsan
// => InitializingBean.afterPropertiesSet()
// => MyBeanPostProcessor.postProcessAfterInitialization(): change sex female

// org.springframework.context.support.ClassPathXmlApplicationContext - Closing org.springframework.context.support.ClassPathXmlApplicationContext@2f0a87b3, started on Tue Jul 07 23:13:37 CST 2020

// => DisposableBean.destroy()
// Human(id=0, name=zhangsan, sex=false)
```



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;总结：为了减少代码的侵入性，不推荐直接使用 InitializingBean 接口和 DisposableBean 接口，可以通过配置\<init-method> 和 \<destroy-method> 来达到相同的目的，当然也可以通过 @PostConstruct 和 @PreDestroy方法注解完成相同操作；一般情况下，除非基于Spring框架定制开发，否则不会用到 BeanNameAware, BeanFactoryAware, ApplicationContextAware, InitializingBean, DisposableBean 这5个接口；而BeanPostProcessor 则完全不同，由于它类似于插件形式供Spring使用，并且基于此之上可以完成注入AOP等重要功能，所以它对于Bean的定制化扩展很重要。