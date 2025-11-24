package kr.bhodu.benjerrysclone.controllers;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

        @Slf4j
        @Controller
        @RequiredArgsConstructor
        public class HomeController {

                // 홈 뷰 렌더링
                @GetMapping({"/home"})
                public String home() {
                        return "pages/home";
                }
        }

