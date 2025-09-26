package kr.bhodu.benjerrysclone.services.impl;

import kr.bhodu.benjerrysclone.mappers.FlavourMapper;
import kr.bhodu.benjerrysclone.models.FlavourSummary;
import kr.bhodu.benjerrysclone.models.VariantDetail;
import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;
import kr.bhodu.benjerrysclone.services.FlavourService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FlavourServiceImpl implements FlavourService {

        private final FlavourMapper flavourMapper;

        @Override
        public Map<String, List<FlavourSummary>> getTopFlavoursGroupedByCategory() {
                List<FlavourSummary> all = flavourMapper.selectAllFlavours();

                return all.stream()
                                .collect(Collectors.groupingBy(
                                                FlavourSummary::getCategoryListSlug, // 카테고리 slug 기준 그룹핑
                                                LinkedHashMap::new,
                                                Collectors.collectingAndThen(
                                                                Collectors.toList(),
                                                                list -> list.stream().limit(5).toList()
                                                )
                                ));
        }


        @Override
        public boolean isCategory(String slug) {
                // mapper 에서 카테고리 slug 존재 여부 확인
                return flavourMapper.existsCategorySlug(slug) > 0;
        }


        @Override
        public Map<String, List<FlavourSummary>> getFlavoursByCategory(String listSlug) {
                List<FlavourSummary> flavours = flavourMapper.selectByCategory(listSlug);

                return flavours.stream().collect(Collectors.groupingBy(
                                f -> {
                                        if (f.isNew()) return "NEW"; // 대문자
                                        switch (f.getFlavourTypeId()) {
                                                case 1: return "ORIGINAL";
                                                case 2: return "CORE";
                                                case 3: return "SORBET";
                                                default: return "OTHER";
                                        }
                                },
                                LinkedHashMap::new,
                                Collectors.toList()
                ));
        }


        @Override
        public VariantDetail getVariantDetail(String flavourSlug, String categorySlug) {
                VariantDetail detail = flavourMapper.selectVariantDetail(flavourSlug, categorySlug);
                if (detail == null) return null;

                Long variantId = detail.getVariantId();
                detail.setMediaList(flavourMapper.selectVariantMedia(variantId));
                detail.setIngredients(flavourMapper.selectVariantIngredients(variantId));
                detail.setSourcingFeatures(flavourMapper.selectVariantSourcing(variantId));
                detail.setDietaryCerts(flavourMapper.selectVariantCerts(variantId));
                detail.setRecommendations(flavourMapper.selectRecommendations(variantId));
                detail.setAvailableCategories(flavourMapper.selectAvailableCategories(detail.getFlavourId()));

                //  다음 variant 정보 세팅
                VariantNavigation next = getNextVariant(variantId);
                detail.setNextVariant(next);

                return detail;
        }

        @Override
        public VariantDetail getVariantDetailDefault(String flavourSlug) {
                VariantDetail detail = flavourMapper.selectVariantDetailDefault(flavourSlug);
                if (detail == null) return null;

                Long variantId = detail.getVariantId();
                detail.setMediaList(flavourMapper.selectVariantMedia(variantId));
                detail.setIngredients(flavourMapper.selectVariantIngredients(variantId));
                detail.setSourcingFeatures(flavourMapper.selectVariantSourcing(variantId));
                detail.setDietaryCerts(flavourMapper.selectVariantCerts(variantId));
                detail.setRecommendations(flavourMapper.selectRecommendations(variantId));
                detail.setAvailableCategories(flavourMapper.selectAvailableCategories(detail.getFlavourId()));

                //  다음 variant 정보 세팅
                VariantNavigation next = getNextVariant(variantId);
                detail.setNextVariant(next);

                return detail;
        }

        @Override
        public VariantNavigation getNextVariant(Long variantId) {
                VariantNavigation next = flavourMapper.findNextVariant(variantId);
                if (next == null) {
                        return flavourMapper.findFirstVariant(); // 마지막이면 첫 번째로 순환
                }
                return next;
        }
}
