package kr.bhodu.benjerrysclone;

import kr.bhodu.benjerrysclone.interceptors.MyInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.web.servlet.config.annotation.*;

@Configuration
@RequiredArgsConstructor
@SuppressWarnings("null")
//@PropertySource(value="classpath:application.properties", encoding = "UTF-8")
public class MyWebConfig implements WebMvcConfigurer {

        // MyInterceptor 객체를 자동 주입 받는다
        // 이 과정에서 myInterceptor 안에 @Autowired로 선언된 UtilHelper 객체도 자동 주입된다.
        @Autowired
        private final MyInterceptor myInterceptor;

        @Override
        public void configurePathMatch(PathMatchConfigurer configurer) {
                configurer.setUseTrailingSlashMatch(true);
        }

        @Override
        public void addInterceptors(InterceptorRegistry registry) {
                // 직접 정의한 MyInterceptor를 Spring에 등록
                InterceptorRegistration ir = registry.addInterceptor(myInterceptor);
                ir.excludePathPatterns("/error", "/robots.txt", "/favicon.ico", "/assets/**");
        }
}
