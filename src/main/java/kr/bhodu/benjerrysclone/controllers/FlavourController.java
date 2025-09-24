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
         *  /flavours/{listSlug}
         * 카테고리 상세 페이지
         */
        @GetMapping("/flavours/{listSlug}")
        public String listByCategory(@PathVariable String listSlug, Model model) {
                List<FlavourSummary> flavours = flavourService.getFlavoursByCategory(listSlug);
                model.addAttribute("flavours", flavours);
                model.addAttribute("listSlug", listSlug);
                return "flavours/category";
        }

        /**
         *  /{flavourSlug}/{categorySlug}
         * 특정 variant 상세 페이지
         */
        @GetMapping("/{flavourSlug}/{categorySlug}")
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
         *  /{flavourSlug}
         * 카테고리 slug 없이 들어온 경우 → 기본 variant (PINT > MINI_CUP > SCOOP)
         */
        @GetMapping("/{flavourSlug}")
        public String productDetailDefault(@PathVariable String flavourSlug, Model model) {
                VariantDetail detail = flavourService.getVariantDetailDefault(flavourSlug);
                if (detail == null) {
                        return "error/404";
                }
                model.addAttribute("detail", detail);
                return "flavours/detail";
        }

        /**
         *  /variant/{variantId}/next
         * 다음 variant navigation (JSON 반환)
         * → 뷰에서 AJAX 호출 후 /{flavourSlug}/{categorySlug}로 이동 가능
         */
        @GetMapping("/variant/{variantId}/next")
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
