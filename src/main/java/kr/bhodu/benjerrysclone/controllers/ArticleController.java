package kr.bhodu.benjerrysclone.controllers;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Slf4j
@Controller
@RequiredArgsConstructor
public class ArticleController {

        // 1) 전체 리스트
        @GetMapping("/whats-new")
        public String listAllNews() {

                return "news/list";
        }


        // 2) article 상세
        @GetMapping("/whats-new/top-ben-jerrys-flavours-of-2022")
        public String newsDetail() {

                return "news/top-ben-jerrys-flavours-of-2022";
        }


}