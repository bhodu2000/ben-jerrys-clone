package kr.bhodu.benjerrysclone.models;

import lombok.Data;

import java.util.List;


@Data
public class VariantReco {
        private int sourceVariantId;
        private int targetVariantId;
        private int slot;
}