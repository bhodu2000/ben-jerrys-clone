package kr.bhodu.benjerrysclone.models;

import lombok.Data;

@Data
public class FlavourSummary {
        private Long variantId;
        private String flavourSlug;
        private String flavourNameKo;
        private String flavourDescriptionKo;
        private boolean isNew;
        private String categorySlug; // (detail URL용)
        private String categoryListSlug;  // (category URL용)
        private String categoryNameKo;    // 카테고리 한글명
        private String imageUrl;          // PACKSHOT 이미지
        private int flavourTypeId;
        private String flavourTypeCode;
}
