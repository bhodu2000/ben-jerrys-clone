package kr.bhodu.benjerrysclone.services;

import kr.bhodu.benjerrysclone.models.FlavourSummary;
import kr.bhodu.benjerrysclone.models.VariantDetail;
import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;

import java.util.List;
import java.util.Map;

public interface FlavourService {

        // /flavours → 카테고리별 상위 5개
        Map<String, List<FlavourSummary>> getTopFlavoursGroupedByCategory();

        // /flavours/{listSlug} → 카테고리 상세 (그룹핑 버전)
        Map<String, List<FlavourSummary>> getFlavoursByCategory(String listSlug);

        // /flavours/{flavourSlug}/{categorySlug} → variant 상세
        VariantDetail getVariantDetail(String flavourSlug, String categorySlug);

        // /flavours/{flavourSlug} → 카테고리 생략 시 기본 variant (우선순위 적용)
        VariantDetail getVariantDetailDefault(String flavourSlug);

        // slug 가 카테고리인지 여부 확인
        boolean isCategory(String slug);

        // /flavours/variant/{variantId}/next → 다음 variant navigation
        VariantNavigation getNextVariant(Long variantId);

        // 검색 결과 화면용
        List<FlavourSummary> searchFlavours(String q);

        // 오토서제스트용: 상위 N개만 */
        List<FlavourSummary> suggestFlavours(String q, int topN);
}