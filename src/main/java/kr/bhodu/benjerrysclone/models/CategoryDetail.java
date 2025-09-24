package kr.bhodu.benjerrysclone.models;

import lombok.Data;
import java.util.List;

@Data
public class CategoryDetail {
        private String categoryNameKo;
        private String listSlug;
        private List<FlavourSummary> newFlavours;
        private List<FlavourSummary> originalFlavours;
        private List<FlavourSummary> coreFlavours;
        private List<FlavourSummary> sorbetFlavours;
}
