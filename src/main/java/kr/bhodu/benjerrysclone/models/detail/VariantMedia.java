package kr.bhodu.benjerrysclone.models.detail;

import lombok.Data;

@Data
public class VariantMedia {
        private Long id;
        private Long variantId;
        private String role;   // PACKSHOT, GALLERY, NUTRITION
        private String url;
        private String altKo;
        private Integer sortOrder;

        // 오타 방지용
        public static final String ROLE_PACKSHOT = "PACKSHOT";
        public static final String ROLE_GALLERY  = "GALLERY";
        public static final String ROLE_NUTRITION= "NUTRITION";
}
