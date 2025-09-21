package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class VariantMedia {
        private int id;
        private int variantId;
        private String role;
        private String url;
        private String altKo;
        private int sortOrder;
        private String fileBasename;
        private int galleryNumPrefix;
}