package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;

@Data
public class Article {
        private int id;
        private String slug;
        private String titleKo;
        private String excerptKo;
        private String contentKo;
        private int isActive;
        private String createdAt;
        private String updatedAt;
        private String publishedAt;
}