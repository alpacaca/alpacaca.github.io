---
title: Spring及源码——SpringBoot（三）
date: 2020-7-1
tags: [Spring, SpringBoot]
---
{% asset_img image1.jpg spring %}

# Spring及源码——SpringBoot（三）
<!--more-->

## 8 SpringBoot 整合 JDBC

1. 导入jdbc相关依赖和数据库驱动。

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <scope>runtime</scope>
</dependency>
```



2. 在配置文件中设置数据源。

```yaml
spring:
  datasource:
    username: root
    password: java
    url: jdbc:mysql://localhost:3306/demo?serverTimezone=UTC&useUnicode=true&characterEncoding=utf-8
    driver-class-name: com.mysql.cj.jdbc.Driver
```



3. 在测试类中测试。

```java
@SpringBootTest
class IntegrateJdbcApplicationTests {

    @Autowired
    DataSource dataSource;

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void contextLoads() throws Exception {
        String sql1 = "insert into tb_user(name) values('lisi')";
        String sql2 = "select * from tb_user";
        jdbcTemplate.execute(sql1);
        List<Map<String, Object>> ret = jdbcTemplate.queryForList(sql2);
        System.out.println(ret);
    }
    // 可以正常调用数据库
    
    @Test
    void datasource() {
        System.out.println(dataSource);
    }
    // 输出 HikariDataSource
}
```

从上述数据源输出中可以看到，SpringBoot 默认使用 Hikari 数据连接池，Hikari  号称当前运行效率最高的数据连接池（期待与Druid的全面比较），通过查询自动配置类 `DataSourceAutoConfiguration` 源码，可以看到目前支持的数据连接池类型。

```java
@Configuration(
    proxyBeanMethods = false
)
@ConditionalOnClass({DataSource.class, EmbeddedDatabaseType.class})
@ConditionalOnMissingBean(
    type = {"io.r2dbc.spi.ConnectionFactory"}
)
// 数据源的参数配置类
@EnableConfigurationProperties({DataSourceProperties.class})
@Import({DataSourcePoolMetadataProvidersConfiguration.class, DataSourceInitializationConfiguration.class})
public class DataSourceAutoConfiguration {

    @Configuration(
        proxyBeanMethods = false
    )
    @Conditional({DataSourceAutoConfiguration.PooledDataSourceCondition.class})
    @ConditionalOnMissingBean({DataSource.class, XADataSource.class})
    // 支持的数据连接池
    @Import({Hikari.class, Tomcat.class, Dbcp2.class, Generic.class, DataSourceJmxConfiguration.class})
    protected static class PooledDataSourceConfiguration {
        protected PooledDataSourceConfiguration() {
        }
    }

    // ...
}
```



### 9 SpringBoot 整合 Druid 数据连接池

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;从上述例子中可以看到 SpringBoot 支持 Hikari、Tomcat、Dbcp2、Generic、DataSourceJmxConfiguration 数据连接池，作为国产优秀开源数据连接池 Druid ，不仅有可观的执行速度，还提供了非常强大的后台监控功能，在技术选型中使用的也非常普遍，所以本节介绍 SpringBoot 整合 Druid 。

1. 导入 Druid 依赖和数据库驱动。

```xml
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <scope>runtime</scope>
</dependency>

<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>druid</artifactId>
    <version>1.1.23</version>
</dependency>

<!-- 如果不引入 log4j 依赖，会导致启动Druid数据源时报错 -->
<dependency>
    <groupId>log4j</groupId>
    <artifactId>log4j</artifactId>
    <version>1.2.17</version>
</dependency>
```

> 如果不导入 log4j ，启动 SpringBoot 可能出现如下错误提示：
>
>  
>
> ***************************
> APPLICATION FAILED TO START
> ***************************
>
> Description:
>
> Failed to bind properties under 'spring.datasource' to javax.sql.DataSource:
>
>     Property: spring.datasource.filters
>     Value: stat,wall,log4j
>     Origin: class path resource [application.yml]:25:14
>     Reason: org.apache.log4j.Priority
>
> Action:
>
> Update your application's configuration



2. 配置自定义数据连接池

```yaml
spring:
  datasource:
    username: root
    password: java
    url: jdbc:mysql://localhost:3306/demo?serverTimezone=UTC&useUnicode=true&characterEncoding=utf-8
    driver-class-name: com.mysql.cj.jdbc.Driver
    # 自定义数据源
    type: com.alibaba.druid.pool.DruidDataSource
```



3. 配置数据连接池相关信息，最终通过 @ConfigurationProperties 将所有数据源信息装配到 Druid 实例对象中。

```yaml
spring:
  datasource:
    username: root
    password: java
    url: jdbc:mysql://localhost:3306/demo?serverTimezone=UTC&useUnicode=true&characterEncoding=utf-8
    driver-class-name: com.mysql.cj.jdbc.Driver
    # 自定义数据源
    type: com.alibaba.druid.pool.DruidDataSource

    #Spring Boot 默认是不注入这些属性值的，需要自己绑定
    #druid 数据源专有配置
    initialSize: 5
    minIdle: 5
    maxActive: 20
    maxWait: 60000
    timeBetweenEvictionRunsMillis: 60000
    minEvictableIdleTimeMillis: 300000
    validationQuery: SELECT 1
    testWhileIdle: true
    testOnBorrow: false
    testOnReturn: false
    poolPreparedStatements: true

    #配置监控统计拦截的filters，stat:监控统计、log4j：日志记录、wall：防御sql注入
    filters: stat,wall,log4j
    maxPoolPreparedStatementPerConnectionSize: 20
    useGlobalDataSourceStat: true
    connectionProperties: druid.stat.mergeSql=true;druid.stat.slowSqlMillis=500
```



4. 将配置信息装配到 Druid Data Source 实例对象中。

```java
@Configuration
public class DruidDataSourceConfig {

    // 将 spring.datasource中的配置信息全部配置到 DruidDataSource 中，不再让 SpringBoot 绑定
    @ConfigurationProperties(prefix = "spring.datasource")
    @Bean
    public DataSource druidDataSource() {
        return new DruidDataSource();
    }
}
```



5. 测试数据连接池

```java
@SpringBootTest
class IntegrateJdbcApplicationTests {

    @Autowired
    DataSource dataSource;

    @Test
    void dataSource() {
        System.out.println(dataSource.getClass());
    }
}
// output:
// class com.alibaba.druid.pool.DruidDataSource
```



6. 采用向 ServletContext 注册的方式提交 Druid 监控 Servlet，通过 `com.alibaba.druid.support.http.ResourceServlet` 可以查看配置参数名，并通过Map保存。

```java
@Configuration
public class DruidDataSourceConfig {

    @ConfigurationProperties(prefix = "spring.datasource")
    @Bean
    public DataSource druidDataSource() {
        return new DruidDataSource();
    }

    // 采用向 ServletContext 注册的方式提交 Druid 监控 Servlet
    @Bean
    public ServletRegistrationBean druidMonitorInit() {
        ServletRegistrationBean servlet = new ServletRegistrationBean(new StatViewServlet(), "/druid/*");

        // com.alibaba.druid.support.http.ResourceServlet 提供配置参数名
        Map<String, String> monitorMap = new HashMap<>();
        monitorMap.put("loginUsername", "admin"); 
        monitorMap.put("loginPassword", "admin"); 

        // 允许访问
        // monitorMap.put("allow", "localhost"); // 只有本机可以访问
        monitorMap.put("allow", ""); // 为空或null，表示允许所有人访问
        // 拒绝访问
        // monitorMap.put("deny", "127.0.0.1"); // 禁止此ip访问

        // 参数初始化
        servlet.setInitParameters(monitorMap);
        return servlet;
    }
}
```



7. 通过 url 访问 `http://localhost:8080/druid/index.html`。



## 10 SpringBoot 整合 MyBatis

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Spring 的 JPA 是 ORM 框架的轻量级封装，默认采用 Hibernate 框架，作为我国 ORM 的主要生产框架，Mybatis 与 SpringBoot 的整合尤为重要。

1. 导入 mybatis 依赖。

```xml
<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
    <version>2.1.1</version>
</dependency>
```



2. 配置文件创建数据源，与 9 小节保持一致，不在复述。除了数据源还可选择其他 Mybatis 配置。

```yaml
# datasource 配置省略
# Mybatis
mybatis:
  type-aliases-package: me.zhy.integrate.entity.domain
  # 由于 IDE 问题，最好将mapper文件放在 classpath 下创建
  mapper-locations: classpath:mybatis/mapper/*.xml
```



2. 创建 User 类 和对应的 Mapper 接口。

```java
@NoArgsConstructor
@AllArgsConstructor
@ToString
public class User {

    @Getter @Setter
    private Integer id;

    @Getter @Setter
    private String name;
}


@Mapper
@Repository
public interface UserMapper {

    List<User> getUsers();

    User getUser(Integer id);
}
```



4. 配置 Mapper 映射文件 UserMapper.xml（创建在 classpath:mybatis/mapper/UserMapper.xml）。

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="me.zhy.integrate.entity.mapper.UserMapper">

    <select id="getUsers" resultType="User">
       select * from tb_user;
    </select>

    <select id="getUser" resultType="User" parameterType="int">
       select * from tb_user where id = #{id};
    </select>

</mapper>
```



5. 测试。

```java
@SpringBootTest
class IntegrateJdbcApplicationTests {

    @Autowired
    private UserMapper userMapper;

    @Test
    void contextLoads() throws Exception {
        List<User> users = userMapper.getUsers();
        System.out.println(users);
    }
}

// output:
// [User(id=1, name=zhangsan), User(id=2, name=lisi), User(id=3, name=lisi)]
```



## 11 SpringBoot 整合 安全框架

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 Web 安全框架领域最常用的分别是 **SpringSecurity 和 Shiro**，本节将分别介绍 SpringBoot 对安全框架的整合以及简单应用。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 Web 安全领域，最重要的两件事是：**认证和授权**，安全框架也主要围绕这主题展开设计。



### 11.1 SpringBoot 整合 SpringSecurity

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SpringSecurity 核心采用一组过滤器链，加持在客户端请求进入接口 API 的过程中。核心组件包括 ：

- WebSecurityConfigurerAdapter，用于自定义 Security 策略；
- AuthenticationManagerBuilder，用于认证策略；
- @EnableWebSecurity：开启安全模式。

{% asset_img 1.png spring %}



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;首先，简单创建几个页面用于测试，包含：index.html，login.html，page1/1.html，page1/2.html，page2/1.html，page2/2.html，通过index.html可以跳转至其他页面。

{% asset_img 2.png spring %}



{% asset_img 3.png spring %}



**使用 SpringSecurity 的具体步骤如下：**

1. 导入spring security 相关依赖。

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

2. 创建 Spring Security 的 Java 配置类，该配置会创建一个过滤器，称为 SpringSecurityFilterChain ，该过滤器链负责主要的安全任务包括：保护应用的URLS、验证提交后的用户名和密码、登录界面重定向等。

 ```java
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    // 授权
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        super.configure(http);
    }
    
    // 认证
    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        super.configure(auth);
    }
}
 ```

由于采用向 ServletContext 动态注册过滤器，可以在不影响正常业务代码的情况下使用，即不具有侵入性。为了更形象的展示 Security 的能力，以下分别对 授权 和 认证 进行测试。



**测试1：授权测试**

```java
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    /**
     * 授权：
     * 对于访问根目录和index页面权限对所有人放行
     * 访问page1下的页面需要用户角色 v1
     * 访问page2下的页面需要用户角色 v2
     */
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.authorizeRequests()
                .antMatchers("/", "/index").permitAll()
                .antMatchers("/page1/**").hasRole("v1")
                .antMatchers("/page2/**").hasRole("v2");

        // 无权限将跳转到登录页，如果没有登录页会跳转 security 提供的默认登录页
        http.formLogin();
    }
    
    // 认证
    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        super.configure(auth);
    }
}
```

经过测试发现 index 页面正常访问，跳转 page1 或 page2 时被拦截并提示 `403`，拒绝访问。

{% asset_img 4.png spring %}



**测试2：认证测试**

```java
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    /**
     * 授权：
     * 对于访问根目录和index页面权限对所有人放行
     * 访问page1下的页面需要用户角色 v1
     * 访问page2下的页面需要用户角色 v2
     */
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http.authorizeRequests()
                .antMatchers("/", "/index").permitAll()
                .antMatchers("/page1/**").hasRole("v1")
                .antMatchers("/page2/**").hasRole("v2");

        // 无权限将跳转到登录页，如果没有登录页会跳转 security 提供的默认登录页
        http.formLogin();
    }

    /**
     * 认证：
     * admin 用户 具有权限 v1 、v2
     * me 用户 具有权限 v1
     *
     * 采用 security 推荐的 BCrypt 加密方式
     */
    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        // 内存中授权
        auth.inMemoryAuthentication().passwordEncoder(new BCryptPasswordEncoder())
                .withUser("admin")
                .password(new BCryptPasswordEncoder().encode("admin"))
                .roles("v1", "v2")

                .and()
                .withUser("me")
                .password(new BCryptPasswordEncoder().encode("me"))
                .roles("v1");
    }
}
```

重启应用后测试，**使用spring security 默认提供的登录框**，当 admin 用户登录后因为具有 v1 和 v2角色，所有页面都可以访问；当 me 用户登录后因为具有 v1 角色，page1 可以正常访问，page2 会被拒绝访问 `403`。

还值得注意一点，在使用 @EnableWebSecurity 开启安全保护之后，默认启用 CSRF（跨站请求攻击），会针对 Patch、Post、Put、Delete进行防护。避免 CSRF 攻击最常用的手段就是客户端每次请求时都需要提交 token ，服务端会比较 token 的一致性，当不一致时会拒绝访问。



### 11.2 SpringBoot 整合 Shiro

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Shiro 是 Apache 下的开源项目，是一个强大且易用的 JAVA 安全框架，安全任务包含验证、授权、加密和会话管理，Shiro 提供了易于理解的 API，可以快速构建。Shiro 包含三个核心组件：SecurityManager、Subject、Realms。

- SecurityManager：它是 Shiro 框架的核心管理器，属于门面对象，提供安全管理的各种服务。
- Subject：“当前操作用户”，它既可以指当前操作用户，也可以指正在执行的第三方进程等。
- Realme：它封装了数据源，向 Shiro 提供相关数据，也就是说，Shiro 会从 Realme 中查找用户权限信息。

{% asset_img 5.png spring %}

1. 导入 shiro 依赖:

```xml
<dependency>
    <groupId>org.apache.shiro</groupId>
    <artifactId>shiro-spring</artifactId>
    <version>1.4.1</version>
</dependency>
```



2. 使用之前整合mybatis的代码，修改数据库，添加 password 字段和  permission 字段，分辨用于管理用户密码和权限。

{% asset_img 6.png shiro%}



同时修改 User 类、UserMapper接口和 UserMapper.xml。

```java
@NoArgsConstructor
@AllArgsConstructor
@ToString
public class User {

    @Getter @Setter
    private Integer id;

    @Getter @Setter
    private String name;

    @Getter @Setter
    private String password;

    @Getter @Setter
    private String permission;
}
```

```xml
@Mapper
@Repository
public interface UserMapper {

    List<User> getUsers();

    User getUserByID(Integer id);

    User getUser(String username);
}

```

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="me.zhy.integrate.entity.mapper.UserMapper">
    <select id="getUsers" resultType="User">
       select * from tb_user;
    </select>

    <select id="getUserByID" resultType="User" parameterType="int">
       select * from tb_user where id = #{id};
    </select>

    <select id="getUser" resultType="User" parameterType="String">
       select * from tb_user where `name` = #{username};
    </select>
</mapper>
```



创建服务类，用于从数据库获取真实数据

```java
@Service
public class UserService {

    private UserMapper userMapper;

    public User getUser(String username) {
        return userMapper.getUser(username);
    }

    @Autowired
    public void setUserMapper(UserMapper userMapper) {
        this.userMapper = userMapper;
    }
}
```



3. 创建自定义 Realme，用于实现授权和验证的具体实现，数据部分采用数据库中的真实 tb_user 数据：

```java
public class UserShiroRealme extends AuthorizingRealm {

    private UserService userService;

    // 授权
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principalCollection) {
        SimpleAuthorizationInfo info = new SimpleAuthorizationInfo();
        Subject subject = SecurityUtils.getSubject();  // 获得当前用户
        User currentUser = (User) subject.getPrincipal();
        info.addStringPermission(currentUser.getPermission()); // 添加当前用户的权限
        return info;
    }

    // 验证
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken authenticationToken)
            throws AuthenticationException {
        // 获得 controller 封装的前台用户名和密码 token
        UsernamePasswordToken token = (UsernamePasswordToken) authenticationToken;
        String username = token.getUsername();
        User user = userService.getUser(username); // 从数据库读取数据
        if (Objects.isNull(user)) {
            // 对象为空，验证失败
            return null;
        }
        String password = user.getPassword();
        // user 将在授权中继续使用， password 将被 shiro 自行密文验证
        return new SimpleAuthenticationInfo(user, password, "");
    }

    @Autowired
    public void setUserService(UserService userService) {
        this.userService = userService;
    }
}
```



4. 创建 Shiro 配置类，向 IOC 容器注册，包含核心组件 Realme、SecurityManager 和 过滤器链 ShiroFilterFactoryBean，其中 SecurityManager 使用与 Web 相关的 DefaultWebSecurityManager：

```java
package me.zhy.integrate.config.shiro;

import me.zhy.integrate.entity.domain.User;
import me.zhy.integrate.service.UserService;
import org.apache.shiro.SecurityUtils;
import org.apache.shiro.authc.*;
import org.apache.shiro.authz.AuthorizationInfo;
import org.apache.shiro.authz.SimpleAuthorizationInfo;
import org.apache.shiro.realm.AuthorizingRealm;
import org.apache.shiro.session.Session;
import org.apache.shiro.subject.PrincipalCollection;
import org.apache.shiro.subject.Subject;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Objects;

public class UserShiroRealme extends AuthorizingRealm {

    private UserService userService;

    // 授权
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principalCollection) {
        SimpleAuthorizationInfo info = new SimpleAuthorizationInfo();
        Subject subject = SecurityUtils.getSubject();  // 获得当前用户
        User currentUser = (User) subject.getPrincipal();
        info.addStringPermission(currentUser.getPermission()); // 添加当前用户的权限
        return info;
    }

    // 验证
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken authenticationToken)
            throws AuthenticationException {
        // 获得 controller 封装的前台用户名和密码 token
        UsernamePasswordToken token = (UsernamePasswordToken) authenticationToken;
        String username = token.getUsername();
        User user = userService.getUser(username); // 从数据库读取数据
        if (Objects.isNull(user)) {
            // 对象为空，验证失败
            return null;
        }
        // 验证成功，将对象放入shiro.Session中
        Subject subject = SecurityUtils.getSubject();
        Session session = subject.getSession();
        session.setAttribute("user", user);
        
        String password = user.getPassword();
        // user 将在授权中继续使用， password 将被 shiro 自行密文验证
        return new SimpleAuthenticationInfo(user, password, "");
    }

    @Autowired
    public void setUserService(UserService userService) {
        this.userService = userService;
    }
}

```

在 step 3 中过滤器链通过 Map<String, String> 方式设置，其中 `key表示拦截的 url 路径，value表示过滤器`，Shiro 在 DefaultFilter 枚举类中提供了多种内置过滤器，这些组件分为两类：认证过滤器和授权过滤器，在文档中介绍如下：



*认证过滤器：*

- anon ：org.apache.shiro.web.filter.authc.AnonymousFilter，*可以匿名使用*
- authc ：org.apache.shiro.web.filter.authc.FormAuthenticationFilter，*需要认证(登录)才能使用*
- authcBasic ：org.apache.shiro.web.filter.authc.BasicHttpAuthenticationFilter，*httpBasic认证*
- user ：org.apache.shiro.web.filter.authz.UserFilter，*示必须存在用户，当登入时不做检查*



*授权过滤器：*

- ssl ：org.apache.shiro.web.filter.authz.SslFilter，*https请求使用*

- port ：org.apache.shiro.web.filter.authz.PortFilter，*参数绑定端口号使用*

- rest ：org.apache.shiro.web.filter.authz.HttpMethodPermissionFilter，*参数绑定rest行为使用，如get*

- perms ：org.apache.shiro.web.filter.authz.PermissionAuthorizationFilter，*权限类别，包含多个参数*

- roles ：org.apache.shiro.web.filter.authz.RolesAuthorizationFilter，*角色类别，包含多个参数*

  

5. 启动 SpringBoot 验证，zhangsan 用户具有 `user:*` 权限可以全部访问；lisi 用户具有 `user:page1` 权限，只能访问 page1 ，page2将提示授权失败；wangwu 用户同理。 



## 12 SpringBoot 集成 Swagger

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Swagger 是一个规范和完整的框架，用于生成、描述、调用和可视化 RESTful 风格的 Web 服务。当前 WEB 项目以前后端分离为主，后端主要提供 REST API 给前端，前端框架负责数据绑定、路由等，所以 Swagger 不仅可以保证前后端开发的一致性和及时性，还能有效提高开发效率。

1. 导入 Swagger 依赖。

```xml
<!-- swagger -->
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger2</artifactId>
    <version>2.9.2</version>
</dependency>
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger-ui</artifactId>
    <version>2.9.2</version>
</dependency>
```



2. 创建 Swagger 配置类并注册到 IOC 容器中

```java
@Configuration
@EnableSwagger2
public class SwaggerConfig {

    // 创建 Swagger 实体类
    @Bean
    public Docket docket(Environment env) {
        // prod 环境关闭 swagger，dev 环境开启
        // 只接收 dev test 环境，不接收 prod 环境
        Profiles profiles = Profiles.of("dev", "test"); 
        boolean useSwagger = env.acceptsProfiles(profiles);

        // SWAGGER_12、SWAGGER_2、SPRING_WEB
        return new Docket(DocumentationType.SWAGGER_2)
            .apiInfo(getApiInfo())
            .groupName("spring boot api release")
            .select()
            // 扫描指定包
            .apis(RequestHandlerSelectors.basePackage("me.zhy.integrate.controller"))    
            // url 过滤策略
            .paths(PathSelectors.any()) 
            .build()
            .enable(useSwagger);
    }

    // 配置信息
    public ApiInfo getApiInfo() {
        Contact contact = new Contact("spring-boot-integrate", "", "");
        return new ApiInfo("Spring Boot Integrate Project",
                           "Api Documentation",
                           "1.0",
                           "",
                           contact,
                           "",
                           "", new ArrayList());
    }
}
```



3. 对 Controller 层接口进行 Swagger 标记。

```java
@RestController
@RequestMapping("/swagger")
public class SwaggerTestController {

    @ApiOperation("欢迎页")
    @GetMapping("/hello")
    public String hello() {
        return "hello";
    }

    @ApiOperation("请求User对象")
    @PostMapping("/hi")
    public User hi() {
        return new User();
    }
}
```



4. 如果 Controller 层的接口有返回的实例对象，那么Swagger就会扫描到并在 UI 中显式，所以在实际开发中可以对DTO创建 Swagger 标记用于说明。

```java
@ApiModel("User实体类")
// lombok 注解
@NoArgsConstructor
@AllArgsConstructor
@ToString
public class User {

    @ApiModelProperty("用户id")
    // lombok 注解
    @Getter @Setter
    private Integer id;

    @ApiModelProperty("用户名")
    @Getter @Setter
    private String name;

    @ApiModelProperty("用户密码")
    @Getter @Setter
    private String password;

    @ApiModelProperty("用户权限")
    @Getter @Setter
    private String permission;
}
```



5. 启动 SpringBoot ，访问 `http://localhost:8080/swagger-ui.html` 访问:

{% asset_img 7.png swagger%}



6. 在 Swagger 页面模拟数据调用接口，如调用本例中的 post 接口。

{% asset_img 8.png swagger%}



## 13 SpringBoot 集成 Redis

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 SpringBoot2.x 版本后，原先 java 版的 redis 工程由 Jedis 更改为 lettuce，jedis 采用源码直连 redis ，在多线程环境中使用是不安全的，为了避免线程安全问题，使用 Jedis Pool 连接池；而 lettuce 采用 netty 与 redis 通信，其实例可以再多个线程中共享，不存在线程安全问题。

**导入 redis 依赖**

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```



**Redis自动配置类和参数配置类**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis自动配置类 RedisAutoConfiguration 只定义了两个模板，即 RedisTemplate 和 StringRedisTemplate，通过 Spring 封装的模版类来简化 Redis 操作。

```java
@Configuration(proxyBeanMethods = false)
@ConditionalOnClass(RedisOperations.class)
@EnableConfigurationProperties(RedisProperties.class)
@Import({ LettuceConnectionConfiguration.class, JedisConnectionConfiguration.class })
public class RedisAutoConfiguration {

   @Bean
   @ConditionalOnMissingBean(name = "redisTemplate")
   public RedisTemplate<Object, Object> redisTemplate(RedisConnectionFactory redisConnectionFactory)
         throws UnknownHostException {
      RedisTemplate<Object, Object> template = new RedisTemplate<>();
      template.setConnectionFactory(redisConnectionFactory);
      return template;
   }

   @Bean
   @ConditionalOnMissingBean
   public StringRedisTemplate stringRedisTemplate(RedisConnectionFactory redisConnectionFactory)
         throws UnknownHostException {
      StringRedisTemplate template = new StringRedisTemplate();
      template.setConnectionFactory(redisConnectionFactory);
      return template;
   }

}
```

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Redis的参数配置类中定义了 Redis 连接的全部信息，其中使用`spring.redis` 前缀的配置信息，配置类中host、 port 已经给出了默认值，并且通过组合的方式集成了 Jedis 对象和 Lettuce 对象。

```java
@ConfigurationProperties(prefix = "spring.redis")
public class RedisProperties {
    /**
	 * Database index used by the connection factory.
	 */
    private int database = 0;

    /**
	 * Connection URL. Overrides host, port, and password. User is ignored. Example:
	 * redis://user:password@example.com:6379
	 */
    private String url;

    /**
	 * Redis server host.
	 */
    private String host = "localhost";

    /**
	 * Login password of the redis server.
	 */
    private String password;

    /**
	 * Redis server port.
	 */
    private int port = 6379;

    /**
	 * Whether to enable SSL support.
	 */
    private boolean ssl;

    /**
	 * Connection timeout.
	 */
    private Duration timeout;

    /**
	 * Client name to be set on connections with CLIENT SETNAME.
	 */
    private String clientName;

    private Sentinel sentinel;

    private Cluster cluster;

    private final Jedis jedis = new Jedis();

    private final Lettuce lettuce = new Lettuce();
```



**自定义 Redis 配置类**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于 RedisAutoConfiguration 中默认使用的 RedisTemplate 采用 \<Object, Object> 形式，而我们常用的是String 类型，与此同时，在 **RedisTemplate** 中默认采用对象序列化方式是 JDK 序列化方式，可以在配置类中自定义序列化方式。

```java
@Configuration
public class RedisConfig {

    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory redisConnectionFactory) {
        RedisTemplate<String, Object> redisTemplate = new RedisTemplate<>();
        redisTemplate.setConnectionFactory(redisConnectionFactory);

        // 配置序列化方式
        Jackson2JsonRedisSerializer jacksonSerializer = new Jackson2JsonRedisSerializer(Object.class);
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.setVisibility(PropertyAccessor.ALL, JsonAutoDetect.Visibility.ANY);
        objectMapper.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);
        jacksonSerializer.setObjectMapper(objectMapper);

        StringRedisSerializer stringSerializer = new StringRedisSerializer();
        // key 使用 String 的序列化方式
        redisTemplate.setKeySerializer(stringSerializer);
        redisTemplate.setHashKeySerializer(stringSerializer);
        // value 使用 jackson 序列化方式
        redisTemplate.setValueSerializer(jacksonSerializer);
        redisTemplate.setHashValueSerializer(jacksonSerializer);
        redisTemplate.afterPropertiesSet();

        return redisTemplate;
    }
}
```

企业级开发中，Pojo对象通常需要序列化，在 redis 中持久化对象，所以默认的 JDK 序列化方式并不能满足现状要求，自定义序列化方式很有必要，更进一步配合自定义封装的 redis 工具类使用，效率翻倍

```java
// 测试
@Autowired
    private RedisTemplate<String, Object> redisTemplate;

    @Test
    void contextLoads() throws Exception {
        User user = new User(1,"张三","123","无权限");
        redisTemplate.opsForValue().set("key1", user);
        System.out.println(redisTemplate.opsForValue().get("key1"));
    }
```



