package kr.bhodu.benjerrysclone.models;

import lombok.Data;

@Data
public class VariantIngredient {
        private int id;
        private int variantId;
        private String ingredientsKo;
        private String smartlabelUrl;
}