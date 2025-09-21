package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class Flavour {
        private int id;
        private String slug;
        private String nameKo;
        private String descriptionKo;
        private int isActive;
        private int isNew;
        private String createdAt;
        private String updatedAt;
}