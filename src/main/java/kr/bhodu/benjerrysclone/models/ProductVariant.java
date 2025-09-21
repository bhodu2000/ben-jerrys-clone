package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class ProductVariant {
        private int id;
        private int flavourId;
        private int categoryId;
        private String variantDescriptionKo;
        private int isActive;
        private int sortOrder;
        private String createdAt;
        private String updatedAt;
}