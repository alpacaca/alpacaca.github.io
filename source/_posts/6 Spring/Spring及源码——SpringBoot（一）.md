---
title: Spring及源码——SpringBoot（一）
date: 2020-7-1
tags: [Spring, SpringBoot]
---
{% asset_img image1.jpg spring %}

# Spring及源码——SpringBoot（一）
<!--more-->

## 1 SpringBoot概述

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring Boot通过大量的集成和自动配置，简化了 Spring 项目开发样板化的配置过程，专注于核心业务的开发，在快速应用开发领域成为领导者。Springboot具有以下特点：

1. IDE 集成了 Spring Initialize 来快速创建 Springboot 项目结构。
2. 通过 maven 配置 springboot 的启动项（spring-boot-starter）来组装项目依赖（spring-boot-starter-dependencies 是核心依赖）。
3. 通过嵌入式 web 容器，并配合主启动类的 main 函数，做到项目工程以 jar 包形式打包并部署，嵌入式 web 容器包括：
   - spring-boot-starter-tomcat
   - spring-boot-starter-jetty
   - spring-boot-starter-undertow

4. 通过 `@SpringBootApplication` 标注 spring 项目入口。@SpringBootApplication 融合了 `@SpringBootConfiguration、@EnableAutoConfiguration、@ComponentScan`注解。
5. 通过 application.properties 或 application.yaml 进行参数化配置，spring 官方推荐使用 yaml 进行配置。



## 2 SpringBoot 简单应用

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过 spring Initializer 快速创建一个 springboot 工程，在 maven 中引入启动项：

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>2.2.2.RELEASE</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>
```

自动生成的 springboot 入口类：

```java
@SpringBootApplication
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }
}
```

手动创建一个 Controller 类

```java
@RestController
public class ControllerDemo {
    
    @GetMapping("/hi")
    public String hi() {
        return "hi";
    }
}
```

运行 main 函数成功启动 springboot 引用，最后在浏览器输入`http://localhost:8080/hi`验证执行成功，一个简单的 Springboot 应用就成功运行。



## 3 SpringBoot 启动源码

### 3.1 自动配置源码

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;该小节仅对 SpringBoot 自动配置进行高层次的展示，通过关键注解和调用类来揭开自动装配的原理。

按照注解调用深度，可以简单的罗列为如下，以缩进表示深度：

```text
@SpringBootApplication
	@SpringBootConfiguration // 配置解析
	@ComponentScan // Bean扫描
	@EnableAutoConfiguration // 自动装配
		@AutoConfigurationPackage
			@Import({Registrar.class})
		@Import({AutoConfigurationImportSelector.class})
			getAutoConfigurationEntry(); // 获得自动配置元素
				getCandidateConfigurations(); // 获得所有候选配置
				getSpringFactoriesLoaderFactoryClass(); // 获得所有标记了@EnableAutoConfiguration的类
				loadSpringFactories(); // 根据类加载器判断从资源或系统中加载 spring.factories 配置项，并通过循环将配置项封装为Properties对象供系统使用
```



> 对于元注解（@Target、@Retention、@Documented、@Inherited）将在源码中省略。



1. @SpringBootApplication，包含`@SpringBootConfiguration、@EnableAutoConfiguration、@ComponentScan`三个主要注解，分别用于实现解析配置、自动装配和组件扫描功能。

```java
@SpringBootConfiguration // 配置解析
@EnableAutoConfiguration // 自动装配
@ComponentScan( // Bean扫描
    excludeFilters = {@Filter(
    type = FilterType.CUSTOM,
    classes = {TypeExcludeFilter.class}
), @Filter(
    type = FilterType.CUSTOM,
    classes = {AutoConfigurationExcludeFilter.class}
)}
)
public @interface SpringBootApplication {}
```



2. @EnableAutoConfiguration 包含两个注解`@AutoConfigurationPackage、@Import({AutoConfigurationImportSelector.class})`，分别实现自动配置包和自动导入类 `AutoConfigurationImportSelector `，其中 @AutoConfigurationPackage 实现了自动导入类 `Registrar`。

```java
@AutoConfigurationPackage
@Import({AutoConfigurationImportSelector.class})
public @interface EnableAutoConfiguration {}

@Import({Registrar.class})
public @interface AutoConfigurationPackage {}
```



3. AutoConfigurationImportSelector 类实现了自动选择导入的配置项：

```java
public class AutoConfigurationImportSelector {

    // 获得自动配置项
    protected AutoConfigurationImportSelector.AutoConfigurationEntry getAutoConfigurationEntry(AutoConfigurationMetadata autoConfigurationMetadata, AnnotationMetadata annotationMetadata) {
        if (!this.isEnabled(annotationMetadata)) {
            return EMPTY_ENTRY;
        } else {
            AnnotationAttributes attributes = this.getAttributes(annotationMetadata);
            // 获取所有候选配置，即标记 EnableAutoConfiguration 注解的类
            List<String> configurations = this.getCandidateConfigurations(annotationMetadata, attributes);

            configurations = this.removeDuplicates(configurations);
            Set<String> exclusions = this.getExclusions(annotationMetadata, attributes);
            this.checkExcludedClasses(configurations, exclusions);
            configurations.removeAll(exclusions);
            configurations = this.filter(configurations, autoConfigurationMetadata);
            this.fireAutoConfigurationImportEvents(configurations, exclusions);
            return new AutoConfigurationImportSelector.AutoConfigurationEntry(configurations, exclusions);
        }
    }


    protected List<String> getCandidateConfigurations(AnnotationMetadata metadata, AnnotationAttributes attributes) {
        // 获得所有标记了 EnableAutoConfiguration 注解的类
        List<String> configurations = SpringFactoriesLoader.loadFactoryNames(this.getSpringFactoriesLoaderFactoryClass(), this.getBeanClassLoader());
        Assert.notEmpty(configurations, "No auto configuration classes found in META-INF/spring.factories. If you are using a custom packaging, make sure that file is correct.");
        return configurations;
    }

    // 返回标记了 EnableAutoConfiguration 注解的类，其实就是@SpringBootApplication
    protected Class<?> getSpringFactoriesLoaderFactoryClass() {
        return EnableAutoConfiguration.class;
    }
    
    public static List<String> loadFactoryNames(Class<?> factoryType, @Nullable ClassLoader classLoader) {
        String factoryTypeName = factoryType.getName();
        return (List)loadSpringFactories(classLoader).getOrDefault(factoryTypeName, Collections.emptyList());
    }

    private static Map<String, List<String>> loadSpringFactories(@Nullable ClassLoader classLoader) {
        MultiValueMap<String, String> result = (MultiValueMap)cache.get(classLoader);
        if (result != null) {
            return result;
        } else {
            try {
                // 根据类加载器判断从资源或系统中获取 spring.factories 配置
                Enumeration<URL> urls = classLoader != null ? classLoader.getResources("META-INF/spring.factories") : ClassLoader.getSystemResources("META-INF/spring.factories");
                LinkedMultiValueMap result = new LinkedMultiValueMap();

                // 遍历所有配置项并封装为 Properties 对象供系统使用，并存入map中返回
                while(urls.hasMoreElements()) {
                    URL url = (URL)urls.nextElement();
                    UrlResource resource = new UrlResource(url);
                    Properties properties = PropertiesLoaderUtils.loadProperties(resource);
                    Iterator var6 = properties.entrySet().iterator();

                    while(var6.hasNext()) {
                        Entry<?, ?> entry = (Entry)var6.next();
                        String factoryTypeName = ((String)entry.getKey()).trim();
                        String[] var9 = StringUtils.commaDelimitedListToStringArray((String)entry.getValue());
                        int var10 = var9.length;

                        for(int var11 = 0; var11 < var10; ++var11) {
                            String factoryImplementationName = var9[var11];
                            result.add(factoryTypeName, factoryImplementationName.trim());
                        }
                    }
                }

                cache.put(classLoader, result);
                return result;
            } catch (IOException var13) {
                throw new IllegalArgumentException("Unable to load factories from location [META-INF/spring.factories]", var13);
            }
        }
    }
}
```

该步骤是主要的自动装配过程：首先，从 `spring.factories` 中读出所有配置项并封装为 Properties 对象，并最终转换为 map 对象，通过标记了 @EnableAutoConfiguration 的类找到所有对应的候选配置项。



4. `spring.factories`，位于`spring-boot-autoconfigure 包 META-INF目录下`

{% asset_img 1.png springboot %}

其内容主要包含以 `AutoConfiguration结尾的自动配置类` ，部分内容节选如下：

```properties
# Auto Configure
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
org.springframework.boot.autoconfigure.admin.SpringApplicationAdminJmxAutoConfiguration,\
org.springframework.boot.autoconfigure.aop.AopAutoConfiguration,\
org.springframework.boot.autoconfigure.amqp.RabbitAutoConfiguration,\
org.springframework.boot.autoconfigure.batch.BatchAutoConfiguration,\
org.springframework.boot.autoconfigure.cache.CacheAutoConfiguration,\
org.springframework.boot.autoconfigure.cassandra.CassandraAutoConfiguration,\
org.springframework.boot.autoconfigure.cloud.CloudServiceConnectorsAutoConfiguration,\
org.springframework.boot.autoconfigure.context.ConfigurationPropertiesAutoConfiguration,\
org.springframework.boot.autoconfigure.context.MessageSourceAutoConfiguration,\
org.springframework.boot.autoconfigure.context.PropertyPlaceholderAutoConfiguration,\
org.springframework.boot.autoconfigure.couchbase.CouchbaseAutoConfiguration,\
org.springframework.boot.autoconfigure.dao.PersistenceExceptionTranslationAutoConfiguration,\
org.springframework.boot.autoconfigure.web.servlet.DispatcherServletAutoConfiguration,\

# 等等，共计 123 项
```

在自动配置类中，有一个关键的以 `@ConditionalOn` 开头的注解，称为 `SpringBoot 条件过滤注解`，用于判断自动配置类是否可用，而是否可用的的根本是工程中是否导入依赖的启动器，即`spring-boot-starter-xxx`，如果导入对应的启动器则自动配置类生效，否则无效。



5. 以 `WebMvcAutoConfiguration` 为例，简单介绍自动配置原理：

```java
// 自带配置
@Configuration( 
    proxyBeanMethods = false
)
// 从配置文件中获得所有 spring.http 配置
@EnableConfigurationProperties({HttpProperties.class})
// 过滤条件1
@ConditionalOnWebApplication( 
    type = Type.SERVLET
)
// 过滤条件2
@ConditionalOnClass({Servlet.class, DispatcherServlet.class, WebMvcConfigurer.class})
// 过滤条件3
@ConditionalOnMissingBean({WebMvcConfigurationSupport.class})
// 自动配置顺序，在SpringApplication.run() 方法中会进行排序
@AutoConfigureOrder(-2147483638)
// 自动配置后执行
@AutoConfigureAfter({DispatcherServletAutoConfiguration.class, TaskExecutionAutoConfiguration.class, ValidationAutoConfiguration.class})
public class WebMvcAutoConfiguration {
    @Bean
    @ConditionalOnBean({View.class})
    @ConditionalOnMissingBean
    public BeanNameViewResolver beanNameViewResolver() {
        BeanNameViewResolver resolver = new BeanNameViewResolver();
        resolver.setOrder(2147483637);
        return resolver;
    }

    @Bean
    @ConditionalOnBean({ViewResolver.class})
    @ConditionalOnMissingBean(
        name = {"viewResolver"},
        value = {ContentNegotiatingViewResolver.class}
    )
    public ContentNegotiatingViewResolver viewResolver(BeanFactory beanFactory) {
        ContentNegotiatingViewResolver resolver = new ContentNegotiatingViewResolver();
        resolver.setContentNegotiationManager((ContentNegotiationManager)beanFactory.getBean(ContentNegotiationManager.class));
        resolver.setOrder(-2147483648);
        return resolver;
    }
    
    // ...
}
```

每一个自动配置对象都标记了 `@Configuration` 表明该类是配置类，内部实现了配置项比如上述例子中以 `@Bean` 标记的视图、视图解析器等装入 IOC 容器中，供 Spring 使用。

同时如果该自动装配对象要生效必须满足以 @ConditionOnXXX 的过滤条件，约束过滤条件就是工程中是否导入了 springboot 启动项。



**总结**：

1. 从标记的 @SpringBootApplication 类开始启动，加载环境中（spring-boot-autoconfigure）的 `/NETA-INFO/spring.factories` 获取`自动配置类`列表（spring boot 2.2.2 当前包含123项）。
2. 每一个自动配置类都实现了 `@Configuration` 注解，表示该类是一个配置类，其内部通过  `@Bean ` 注解向IOC 容器中注入依赖对象。
3. 自动配置类生效的约束条件是满足 `@ConditionalOnXXX` 注解的，判断约束条件的根本是是否导入了相关的启动器，或者自定义方法是否满足，如果不生效则不进行自动配置。也就是说 SpringBoot 通过自动配置类内的默认配置项完成了 Spring 的配置，而自动配置类中需要的参数通过配置文件输入，通过@EnableConfigurationProperties 和 @ConfigurationProperties 完成。
4. 通过 AutoConfigurationImportSelector 类，从标记了 @EnableConfiguration 注解类中（即@SpringBootApplication）筛选出需要使用的自动配置类，并最终向 IOC 容器中注册 Bean 对象实例。
5. 如果我们需要的组件不在自动配置类中，那么就需要通过 JavaConfig 方式（@Configuration 和 @Bean）向IOC容器注册。

### 3.2 主启动项源码初探

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这一小节围绕 SpringApplication.run() 方法探究，配合源码和执行流程图来说明。

```java
@SpringBootApplication
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }
}
```



{% asset_img 2.png springboot %}



1. SpringApplication 对象的创建，将传入的主类当作主启动项，通过构造器完成参数初始化，这一步主要功能包括：判断是否 web 工程、加载初始化器、加载监听、推断并设置main方法的定义类。

```java
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
    this.sources = new LinkedHashSet();
    this.bannerMode = Mode.CONSOLE;
    this.logStartupInfo = true;
    this.addCommandLineProperties = true;
    this.addConversionService = true;
    this.headless = true;
    this.registerShutdownHook = true;
    this.additionalProfiles = new HashSet();
    this.isCustomEnvironment = false;
    this.lazyInitialization = false;
    this.resourceLoader = resourceLoader;
    Assert.notNull(primarySources, "PrimarySources must not be null");
    this.primarySources = new LinkedHashSet(Arrays.asList(primarySources));
    // 推断是否 web 工程
    this.webApplicationType = WebApplicationType.deduceFromClasspath();
    // 加载初始化启动器
    this.setInitializers(this.getSpringFactoriesInstances(ApplicationContextInitializer.class));
    // 设置监听器
    this.setListeners(this.getSpringFactoriesInstances(ApplicationListener.class));
    // 推断并设置主类
    this.mainApplicationClass = this.deduceMainApplicationClass();
}
```



2. run方法的主方法运行，这一部是主方法，主要完成各种参数的初始化并最终创建一个 `ConfigurableApplicationContext` 类型的上下文对象，完成 IOC 容器的初始化。

```java
public ConfigurableApplicationContext run(String... args) {
    // 任务监听对象，记录任务执行时间
    StopWatch stopWatch = new StopWatch();
    stopWatch.start();
    ConfigurableApplicationContext context = null;
    Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList();
    
    // 设置headless，使 awt 组件可以在无外设情况下正常使用
    this.configureHeadlessProperty();
    
    // 设置并启动监听器
    SpringApplicationRunListeners listeners = this.getRunListeners(args);
    listeners.starting();
    Collection exceptionReporters;
    try {
        ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);
        // 环境参数准备，properties或yaml配置文件加载
        ConfigurableEnvironment environment = this.prepareEnvironment(listeners, applicationArguments);
        this.configureIgnoreBeanInfo(environment);
        
        // 打印banner （控制台logo）
        Banner printedBanner = this.printBanner(environment);
        
        // 创建一个基于注解的 IOC 容器对象，包含：web ioc、standard ioc 和 响应式 ioc
        context = this.createApplicationContext();
        // 创建Spring异常报告器
        exceptionReporters = this.getSpringFactoriesInstances(SpringBootExceptionReporter.class, new Class[]{ConfigurableApplicationContext.class}, context);
        // ioc容器前置处理：向ioc注册配置参数、监听器、日志等信息并刷新
        this.prepareContext(context, environment, listeners, applicationArguments, printedBanner);
        this.refreshContext(context);
        this.afterRefresh(context, applicationArguments);
        stopWatch.stop();
        // 启动日志创建
        if (this.logStartupInfo) {
            (new StartupInfoLogger(this.mainApplicationClass)).logStarted(this.getApplicationLog(), stopWatch);
        }

        // 启动 ioc 容器
        listeners.started(context);
        this.callRunners(context, applicationArguments);
    } catch (Throwable var10) {
        this.handleRunFailure(context, var10, exceptionReporters, listeners);
        throw new IllegalStateException(var10);
    }

    try {
        // 发布可用的 IOC 容器并返回实例对象
        listeners.running(context);
        return context;
    } catch (Throwable var9) {
        this.handleRunFailure(context, var9, exceptionReporters, (SpringApplicationRunListeners)null);
        throw new IllegalStateException(var9);
    }
}
```



### 3.3 debug模式查看启动

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在配置文件中，通过 `debug = true` 开启调试模式，查看自动配置类的创建和过滤过程。

```yaml
# application.yml
debug: true
```

```
============================
CONDITIONS EVALUATION REPORT
============================

// 启动的自动配置类
Positive matches:
-----------------

AopAutoConfiguration matched:
- @ConditionalOnProperty (spring.aop.auto=true) matched (OnPropertyCondition)

AopAutoConfiguration.ClassProxyingConfiguration matched:
- @ConditionalOnMissingClass did not find unwanted class 'org.aspectj.weaver.Advice' (OnClassCondition)
- @ConditionalOnProperty (spring.aop.proxy-target-class=true) matched (OnPropertyCondition)

DispatcherServletAutoConfiguration matched:
- @ConditionalOnClass found required class 'org.springframework.web.servlet.DispatcherServlet' (OnClassCondition)
- found 'session' scope (OnWebApplicationCondition)

DispatcherServletAutoConfiguration.DispatcherServletConfiguration matched:
- @ConditionalOnClass found required class 'javax.servlet.ServletRegistration' (OnClassCondition)
- Default DispatcherServlet did not find dispatcher servlet beans (DispatcherServletAutoConfiguration.DefaultDispatcherServletCondition)

DispatcherServletAutoConfiguration.DispatcherServletRegistrationConfiguration matched:
- @ConditionalOnClass found required class 'javax.servlet.ServletRegistration' (OnClassCondition)
- DispatcherServlet Registration did not find servlet registration bean (DispatcherServletAutoConfiguration.DispatcherServletRegistrationCondition)

...etc

// 未使用，过滤调的自动配置类
Negative matches:
-----------------

ActiveMQAutoConfiguration:
Did not match:
- @ConditionalOnClass did not find required class 'javax.jms.ConnectionFactory' (OnClassCondition)

AopAutoConfiguration.AspectJAutoProxyingConfiguration:
Did not match:
- @ConditionalOnClass did not find required class 'org.aspectj.weaver.Advice' (OnClassCondition)

ArtemisAutoConfiguration:
Did not match:
- @ConditionalOnClass did not find required class 'javax.jms.ConnectionFactory' (OnClassCondition)

BatchAutoConfiguration:
Did not match:
- @ConditionalOnClass did not find required class 'org.springframework.batch.core.launch.JobLauncher' (OnClassCondition)

CacheAutoConfiguration:
Did not match:
- @ConditionalOnBean (types: org.springframework.cache.interceptor.CacheAspectSupport; SearchStrategy: all) did not find any beans of type org.springframework.cache.interceptor.CacheAspectSupport (OnBeanCondition)
Matched:
- @ConditionalOnClass found required class 'org.springframework.cache.CacheManager' (OnClassCondition)

...etc
```





## 4 SpringBoot配置和yaml

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SpringBoot的全量配置如下 https://docs.spring.io/spring-boot/docs/2.2.2.RELEASE/reference/htmlsingle/#appendix ，在springboot的加载配置文件时按照如下顺序：application.yml > application.yaml > application.properties`，前两者都是yaml文件也是官方推荐使用的配置方式。

### 4.1 yaml的配置注入

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;yaml不仅支持参数配置，还支持对象和容器的配置，在SpringBoot中，可以通过配置 `@ConfigurationProperties(prefix = "")` 从yaml中读取对象并绑定到实例对象中。

1. 在yaml中配置对象

```yaml
person:
  name: zhang
  age: ${random.int[0,30]}
  dog: {type: Alaska, name: wangwang}
  map: {k1: v1, k2: v2}
  list: [a1, a2, a3]
```



2. 创建类，通过@ConfigurationProperties(prefix = "person") 指定yaml中的person绑定到该类中

```java
@Component
@ConfigurationProperties(prefix = "person")
@Data
public class Person {
    private String name;
    private Integer age;
    private Dog dog;
    private List<String> list;
    private Map<String, String> map;
}
```

3. 测试

```java
@SpringBootTest
class TestApplicationTests {

    @Autowired
    private Person person;

    @Test
    void test01() {
        System.out.println(person);
    }

}
// output
// Person(name=zhang, age=29, dog=Dog(type=Alaska, name=wangwang), list=[a1, a2, a3], map={k1=v1, k2=v2})
```

当然，该注解同样支持properties的对象绑定，如果项目路径下包含多个配置文件可以通过 `@PropertySource(value = "application.yaml")`指定。



### 4.2 多环境配置

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实际应用开发中经常需要配置多种环境：测试环境、开发环境、生产环境，正对不同的环境需要进行不同的配置，springboot中支持在配置文件中创建多环境。在 SpringBoot 启动过程中，会按照一定的优先级加载配置文件，官方给出的加载顺序如下：

> Config locations are searched in reverse order. By default, the configured locations are `classpath:/,classpath:/config/,file:./,file:./config/`. The resulting search order is the following:
>
> 1. `file:./config/`
> 2. `file:./`
> 3. `classpath:/config/`
> 4. `classpath:/`

也就是说，当存在多个路径下的配置时，优先加载项目路径下的 config 目录内配置，随后是项目下的配置，接着是类路径下的 config 目录内配置，最后才是类路径下的配置。可以通过路径覆盖来达到不同环境配置文件的替换，但这并不优雅，可以采取多配置文件激活的方式配置，如下:

1. 首先在 classpath 下创建多个配置文件: **application.yml、application-test.yml、application-dev.yml、application-prod.yml**；
2. 通过在 application.yml中配置加载指定配置文件即可，`spring.profiles.active=prod`，就会去加载`application-prod.yml`内的配置。

当然，最优雅的方式应该是在同一配置文件配置多个环境并根据环境激活:

```yaml
server:
  port: 8080
spring:
  profiles:
    active: dev

# 使用---拆分多环境
---
server:
  port: 8081
spring:
  profiles: dev
  
---
server:
  port: 8082
spring:
  profiles: test

---
server:
  port: 8083
spring:
  profiles: prod
```



## 5 自定义启动器 Starter

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring官方支持自定义启动器，并按照 COC 要求创建自定义的启动器建议采用 `xxx-spring-boot-starter` 创建。在日常开发中，有很多独立于业务之外的配置模块，通常的做法是采用 jar 包的形式在其他工程内引入并使用，而在 springboot 中完全可以将这样的模块组成微服务并通过自定义启动器的形式在其他工程中引入。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;创建一个自定义的启动器，完全可以采用官方 spring-boot-autoconfiguration 中的做法，即通过自动装配来完成，具体步骤包括如下：

1. 创建一个满足约定启动器名称的工程，如 `my-spring-boot-starter`，引入相关依赖。
2. 创建一个普通业务类，该类实现具体业务功能。
3. 创建一个参数配置类，该类通过 @ConfigurationProperties 从配置文件中读取相关配置参数。
4. 创建一个自动装配类，依葫芦画瓢，以 AutoConfiguration 作为类名后缀，并配合 @Configuration、@Bean组成配置类向 ioc 容器中注册，同时使用 @EnableConfigurationProperties 指定该装配类所依赖的参数配置类，最后通过设置 @ConditionalOnXXX 注解进行有效过滤。
5. 在 classpath 下创建 `META-INF\spring.factories`，设置自动装配类全路径。
6. 最后，通过 maven 工程打包上传本地仓库供其他工程使用。



1. 创建工程 **my-spring-boot-starter**，引入相关依赖。

   {% asset_img 3.png spring %}



```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>2.2.2.RELEASE</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
    </dependency>
    
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-configuration-processor</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```



2. 创建普通业务类，该业务类对外提供相应的功能。

```java
package me.zhy.starter;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class MyService {
    private MyProperties myProperties;

    public String foo() {
        return myProperties.getParam1() + "#" + myProperties.getParam2();
    }
}
```



3. 创建一个业务配置类，通过 @ConfigurationProperties 从配置文件中读取相关配置参数。

```java
package me.zhy.starter;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

// 读取所有以 my.config 开头的配置信息
@ConfigurationProperties(prefix = "my.config")
@Data
public class MyProperties {
    private String param1;

    private String param2;
}
```



4. 创建一个自动装配类，该类是实现自动配置的核心。

```java
package me.zhy.starter;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(MyProperties.class)
@ConditionalOnWebApplication // 仅限web工程
public class MyServiceAutoConfiguration {

    private MyProperties myProperties;

    @Bean
    public MyService instant() {
        return new MyService(myProperties);
    }

    @Autowired
    public void setMyProperties(MyProperties myProperties) {
        this.myProperties = myProperties;
    }
}

```



5. 在 classpath 下创建 `META-INF\spring.factories`，设置自动装配类全路径。

```properties
org.springframework.boot.autoconfigure.EnableAutoConfiguration=me.zhy.starter.MyServiceAutoConfiguration
```



6. 通过 maven 向本地仓库安装工程

```txt
mvn clean install
```



7. 重新创建工程并引入 step 6 中的启动器工程

```xml
<dependency>
    <groupId>me.zhy</groupId>
    <artifactId>my-spring-boot-starter</artifactId>
    <version>1.0-SNAPSHOT</version>
</dependency>
```



8. 配置 application.properties 文件。

```properties
my.config.param1=param1
my.config.param2=param2
```



9. 创建一个简单的 web 控制器并测试。

```java
import me.zhy.starter.MyService;

@RestController
public class myController {

    @Autowired
    private MyService myService;

    @GetMapping("/test")
    public String test() {
        return myService.foo();
    }

}

// 启动 springboot ，在浏览器中输入 localhost:8080/test 测试
// output: param1 # param2
```

