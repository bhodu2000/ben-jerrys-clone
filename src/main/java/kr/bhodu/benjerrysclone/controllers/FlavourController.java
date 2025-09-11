package kr.bhodu.benjerrysclone.controllers;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;

@Slf4j
@Controller
@RequiredArgsConstructor
public class FlavourController {

        // 1) 전체 리스트
        @GetMapping("/flavours")
        public String listAll() {

                return "flavours/list";
        }

        // 2) 카테고리별 리스트
        //category.list_slug
        @GetMapping("/flavours/{category}")
        public String listByCategory(@PathVariable String category,
                                     Model model) {
                model.addAttribute("category", category);
                return "flavours/category";
        }

        // 3-1) variant 상세
        // slug만 들어온 경우: 우선순위(PINT > MINICUP > SCOOP) 로직 호출
        //category.slug
        @GetMapping("/{slug}")
        public String productDetail(@PathVariable String slug,
                                    Model model) {
                model.addAttribute("slug", slug);
                model.addAttribute("category", "scoop-shop"); //임시
                return "flavours/detail";
        }


        // 3-2) variant 상세
        // slug + category 들어온 경우: 해당 카테고리 강제
        //category.slug
        @GetMapping("/{slug}/{category}")
        public String productDetailByCategory(@PathVariable String slug,
                                              @PathVariable String category,
                                              Model model) {
                model.addAttribute("slug", slug);
                model.addAttribute("category", category);
                return "flavours/detail";
        }


        // 키워드 검색
        @GetMapping("/search")
        public String search() {

                return "flavours/search-results";
        }
}
