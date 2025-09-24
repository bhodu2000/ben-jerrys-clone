package kr.bhodu.benjerrysclone.models.detail;

import lombok.Data;

@Data
public class VariantNavigation {
        private Long variantId;     // 다음 variant의 ID
        private String flavourSlug; // 다음 variant의 flavour.slug
        private String categorySlug; // 다음 variant의 category.slug
}
