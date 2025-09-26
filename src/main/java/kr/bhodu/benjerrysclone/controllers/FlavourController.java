package kr.bhodu.benjerrysclone.controllers;

import kr.bhodu.benjerrysclone.models.FlavourSummary;
import kr.bhodu.benjerrysclone.models.VariantDetail;
import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;
import kr.bhodu.benjerrysclone.services.FlavourService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@Controller
@RequiredArgsConstructor
public class FlavourController {

        private final FlavourService flavourService;

        /**
         *  /flavours
         * 메인 페이지: 카테고리별 상위 5개씩
         */
        @GetMapping("/flavours")
        public String listAllFlavours(Model model) {
                Map<String, List<FlavourSummary>> categories = flavourService.getTopFlavoursGroupedByCategory();
                model.addAttribute("categories", categories);
                return "flavours/list";
        }


        /**
         * Spring url 충돌 방지용 통합 handler
         *
         * /flavours/{listSlug} 카테고리 상세 페이지
         * or
         * /flavours/{flavourSlug}  카테고리 slug 없이 들어온 경우 → 기본 variant (PINT > MINI_CUP > SCOOP)
         */
        @GetMapping("/flavours/{slug}")
        public String handleSlug(@PathVariable String slug, Model model) {
                // 1. 카테고리 listSlug 인지 확인
                if (flavourService.isCategory(slug)) {
                        Map<String, List<FlavourSummary>> groupedFlavours = flavourService.getFlavoursByCategory(slug);
                        model.addAttribute("groupedFlavours", groupedFlavours);
                        model.addAttribute("listSlug", slug);
                        return "flavours/category";
                }

                // 2. 아니면 제품 slug 로 간주
                VariantDetail detail = flavourService.getVariantDetailDefault(slug);
                if (detail == null) {
                        return "error/404";
                }
                model.addAttribute("detail", detail);
                return "flavours/detail";
        }


        /**
         *  /flavours/{flavourSlug}/{categorySlug}
         * 특정 variant 상세 페이지
         */
        @GetMapping("/flavours/{flavourSlug}/{categorySlug}")
        public String productDetailByCategory(@PathVariable String flavourSlug,
                                              @PathVariable String categorySlug,
                                              Model model) {
                VariantDetail detail = flavourService.getVariantDetail(flavourSlug, categorySlug);
                if (detail == null) {
                        return "errors/404"; // 없는 경우 에러 페이지로
                }
                model.addAttribute("detail", detail);
                return "flavours/detail";
        }


        /**
         *  /variant/{variantId}/next
         * 다음 variant navigation (JSON 반환)
         * → 뷰에서 AJAX 호출 후 /{flavourSlug}/{categorySlug}로 이동 가능
         */
        @GetMapping("/flavours/variant/{variantId}/next")
        @ResponseBody
        public VariantNavigation getNextVariant(@PathVariable Long variantId) {
                return flavourService.getNextVariant(variantId);
        }

        // 키워드 검색
        @GetMapping("/search")
        public String search() {

                return "flavours/search-results";
        }
}
