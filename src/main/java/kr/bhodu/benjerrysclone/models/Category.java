package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class Category {
        private int id;
        private String code;
        private String slug;
        private String listSlug;
        private String nameKo;
        private int priority;
        private String packshotBasename;
        private String nutritionBasename;
}
