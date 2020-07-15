---
title: 使用Swagger
date: 2020-6-20
tags: [第三方工具, swagger]
---
{% asset_img image1.jpg swagger%}

# 使用Swagger
<!--more-->

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Swagger 是一个规范和完整的框架，用于生成、描述、调用和可视化 RESTful 风格的 Web 服务。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;当前 WEB 项目以前后端分离为主，后端主要提供 REST API 给前端，前端框架负责数据绑定、路由等，所以 Swagger 不仅可以保证前后端开发的一致性和及时性，还能有效提高开发效率。

## 1 Swagger 导入

``` xml
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger2</artifactId>
    <version>2.6.1</version>
</dependency>
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-swagger-ui</artifactId>
    <version>2.6.1</version>
</dependency>
```



创建 Swagger 配置类相 IOC 容器注册。

```java
@Configuration
@EnableSwagger2
public class Swagger {

    @Bean
    public Docket docket(){
        return new Docket(DocumentationType.SWAGGER_2)
            .apiInfo(apiInfo())
            .select()
            .apis(RequestHandlerSelectors
                  .basePackage(xxx.xxx.controller"))
            .paths(PathSelectors.any())
            .build();
    }

    public ApiInfo apiInfo(){
        return new ApiInfoBuilder()
            .title("swagger title")
            .description("swagger desc")
            .termsOfServiceUrl("")
            .version("1.0")
            .build();
    }
}
```





## 2 Swagger 注解

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Swagger 注解用于 Controller 层，系统运行后会自动扫描注解并最终通过 web-ui 展示。

- @Api : 用在类上，说明该类的主要作用。

- @ApiOperation：用在方法上，给API增加方法说明；

- @ApiImplicitParams : 用在方法上，包含一组参数说明；

- @ApiImplicitParam：用来注解来给方法入参增加说明。

- @ApiResponses：用于表示一组响应。

- @ApiResponse：用在@ApiResponses中，一般用于表达一个错误的响应信息

- @ApiModel：用在返回对象类上，描述一个Model的信息（一般用在请求参数无法使用@ApiImplicitParam注解进行描述的时候）



```java
@RestController
@RequestMapping("/emp")
@Api(value = "用户管理类")
public class EmployeeController {

    @Autowired
    private EmployeeReposiroty employeeReposiroty;

    @PostMapping(value = "/employee")
    @ApiOperation(value = "新增用户", notes = "返回新增对象")
    @ApiImplicitParam(paramType = "query", name = "employee", value = "用户", required = true)
    @ApiResponse(code = 400, message = "参数错误", response = String.class)
    public String insert(Employee employee){
        // ...
    }

    
    @DeleteMapping(value = "/employee/{id}")
    @ApiOperation(value = "删除用户",notes = "id删除用户")
    @ApiImplicitParam(paramType = "path",name = "id",value = "用户id",required = true,dataType = "Integer")
    @ApiResponse(code = 400,message = "参数错误",response = String.class)
    public String delete(@PathVariable("id")Integer id){
        // ...
    }

    
    @PutMapping(value = "/employee/{id}")
    @ApiOperation(value = "修改信息",notes = "id修改用户")
    public String update(Employee employee){
        // ...
    }

    
    @GetMapping(value = "/employee/query")
    @ApiOperation(value = "查询用户",notes = "升序查询用户")
    public List<Employee> findAll(){
        // ...
    }

    
    @GetMapping(value = "/employee/query/page")
    @ApiOperation(value = "分页查询",notes = "")
    @ApiImplicitParams({
        @ApiImplicitParam(paramType = "query",name = "sort",value = "排序:asc|desc",dataType = "String",required = true),
        @ApiImplicitParam(paramType = "query",name = "pagenumber",value = "第几页",dataType = "Integer",required = true),
        @ApiImplicitParam(paramType = "query",name = "pageSize",value = "分页数",dataType = "Integer",required = true)
    })
    public List<Employee> findAllByPage(String sort,Integer pagenumber,Integer pageSize){
        // ....
    }
    
}
```



## 3 Swagger 界面和操作

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过地址 `http://localhost:8080/swagger-ui.html` 访问 swagger ui页面。

{% asset_img 1.png swagger%}



在页面端模拟数据访问接口

{% asset_img 2.png swagger%}

