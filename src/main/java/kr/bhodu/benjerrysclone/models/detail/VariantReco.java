package kr.bhodu.benjerrysclone.models.detail;

import lombok.Data;

@Data
public class VariantReco {
        private Long targetVariantId;
        private String flavourNameKo;
        private String packshotUrl;
        private String flavourSlug;
        private String categorySlug;
}