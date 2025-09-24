package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class VariantDetail {
        private Long variantId;
        private String flavourSlug;
        private String flavourNameKo;
        private String flavourDescriptionKo;
        private boolean isNew;
        private String categoryListSlug;
        private String categoryNameKo;

        // 상세 데이터
        private List<Media> mediaList;
        private Ingredients ingredients;
        private List<SourcingFeature> sourcingFeatures;
        private List<DietaryCert> dietaryCerts;
        private List<FlavourSummary> recommendations;

        @Data
        public static class Media {
                private String role;    // PACKSHOT, GALLERY, NUTRITION
                private String url;
                private String altKo;
        }

        @Data
        public static class Ingredients {
                private String ingredientsKo;
                private String smartlabelUrl;
        }

        @Data
        public static class SourcingFeature {
                private String nameKo;
                private String iconUrl;
        }

        @Data
        public static class DietaryCert {
                private String nameKo;
                private String iconUrl;
        }
}