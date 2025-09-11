package kr.bhodu.benjerrysclone.helpers;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;

@Slf4j
@Component
public class WebHelper {

        private HttpServletRequest request;
        private HttpServletResponse response;

        private String cookieDomain; // 기본 도메인 설정 (필요 시 설정 가능)
        private String cookiePath; // 기본 경로 설정

        @Autowired
        public WebHelper(HttpServletRequest request, HttpServletResponse response,
                         @Value("${spring.cookie.domain}") String cookieDomain,
                         @Value("${spring.cookie.path}") String cookiePath) {
                this.request = request;
                this.response = response;
        }

        /** 클라이언트의 IP 주소를 가져오는 메서드
         *  여러가지 방법으로 시도하고 가장 적합한 IP 주소를 반환합니다.
         *
         * @return IP 주소
         */
        public String getClientIp() {
            String ip = request.getHeader("X-Forwarded-For");

            if (ip == null) {
                 ip = request.getHeader("Proxy-Client-IP");
            }
            if (ip == null) {
                ip = request.getHeader("WL-Proxy-Client-IP"); // 웹로직
            }
            if (ip == null) {
                ip = request.getHeader("HTTP_CLIENT_IP");
            }
            if (ip == null) {
                ip = request.getHeader("HTTP_X_FORWARDED_FOR");
            }
            if (ip == null) {
                    ip = request.getRemoteAddr();
            }

            return ip;
        }

        /**
         *  쿠키값을 저장한다.
         *
         * @param name - 쿠키 이름
         * @param value - 쿠키 값
         * @param maxAge - 쿠키 유효 시간 (0이면 지정 안함, 음수일 경우 즉시 삭제)
         */
         public void writeCookie(String name, String value, int maxAge) {
                if (value != null && !value.equals("")) {
                        try {
                                // -> import java.net.URLEncoder;
                                value = URLEncoder.encode(value, "utf-8");
                        } catch (UnsupportedEncodingException e) {
                                // -> import java.io.UnsupportedEncodingException;
                                e.printStackTrace();
                        }
                }

                // --> import jakarta.servlet.http.Cookie;
                 Cookie cookie = new Cookie(name, value);

                // 쿠키의 도메인 설정 --> application.properties에서 설정된 값을 사용
                 cookie.setDomain(this.cookieDomain);
                 // 쿠키의 유효 경로 설정 --> application.properties에서 설정된 값을 사용
                 cookie.setPath(this.cookiePath);

                 // 쿠키가 Javascript에서 접근하지 못하도록 설정
                 cookie.setHttpOnly(true);

                 // 쿠키 유효시간 설정
                 // 설정하지 않으면 브라우저를 닫기 전까지 유지됨
                 // 0 미만으로 설정하면 즉시 삭제됨
                 // 즉, -1로 설정하면 즉시 삭제, 0으로 설정하면 브라우저를 닫기 전까지 유지됨
                 if (maxAge != 0) {
                         cookie.setMaxAge(maxAge);
                 }

                 response.addCookie(cookie);
         }

        /**
         * 쿠키값을 삭제한다.
         *
         * @param name - 쿠키 이름
         */
         public void deleteCookie(String name) {
                 this.writeCookie(name, null, -1);
         }
}
