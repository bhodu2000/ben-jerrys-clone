package kr.bhodu.benjerrysclone.services;

import kr.bhodu.benjerrysclone.models.FlavourSummary;
import kr.bhodu.benjerrysclone.models.VariantDetail;
import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;

import java.util.List;
import java.util.Map;

public interface FlavourService {

        // /flavours → 카테고리별 상위 5개
        Map<String, List<FlavourSummary>> getTopFlavoursGroupedByCategory();

        // /flavours/{listSlug} → 카테고리 상세
        List<FlavourSummary> getFlavoursByCategory(String listSlug);

        // /{flavourSlug}/{categorySlug} → variant 상세
        VariantDetail getVariantDetail(String flavourSlug, String categorySlug);

        // /{flavourSlug} → 카테고리 생략 시 기본 variant (우선순위 적용)
        VariantDetail getVariantDetailDefault(String flavourSlug);

        // /variant/{variantId}/next → 다음 variant navigation
        VariantNavigation getNextVariant(Long variantId);
}