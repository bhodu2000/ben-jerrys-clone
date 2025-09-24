package kr.bhodu.benjerrysclone.models;

import lombok.Data;

@Data
public class FlavourSummary {
        private Long variantId;
        private String flavourSlug;
        private String flavourNameKo;
        private boolean isNew;
        private String categoryListSlug;  // list_slug (URL용)
        private String categoryNameKo;    // 카테고리 한글명
        private String imageUrl;          // PACKSHOT 이미지
}
