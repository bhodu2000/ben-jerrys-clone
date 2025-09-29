package kr.bhodu.benjerrysclone.models;

import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;
import lombok.Data;

import java.util.List;

@Data
public class VariantDetail {
        private Long flavourId;
        private Long variantId;
        private String flavourSlug;
        private String flavourNameKo;
        private String flavourDescriptionKo;
        private String variantDescriptionKo;
        private boolean isNew;
        private String categorySlug;
        private String categoryListSlug;
        private String categoryNameKo;
        private VariantNavigation nextVariant;

        // 상세 데이터
        private List<Media> mediaList;

        //  역할별 접근자
        private List<Media> galleryList; // 갤러리
        private Media packshot;          // 1장
        private Media nutrition;         // 1장


        private Ingredients ingredients;
        private List<SourcingFeature> sourcingFeatures;
        private List<DietaryCert> dietaryCerts;
        private List<FlavourSummary> recommendations;
        private List<AvailableCategory> availableCategories;

        @Data
        public static class Media {
                private String role;    // PACKSHOT, GALLERY, NUTRITION
                private String url;
                private String altKo;
                private Integer sortOrder;
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

        @Data
        public static class AvailableCategory {
                private String code;       // PINT, MINI_CUP, SCOOP
                private String slug;       // pint, mini-cup, scoop-shop
                private String nameKo;     // 파인트, 미니컵, 스쿱샵
                private Long variantId;
        }
}