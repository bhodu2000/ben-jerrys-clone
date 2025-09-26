package kr.bhodu.benjerrysclone.mappers;

import kr.bhodu.benjerrysclone.models.FlavourSummary;
import kr.bhodu.benjerrysclone.models.VariantDetail;
import kr.bhodu.benjerrysclone.models.detail.VariantNavigation;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface FlavourMapper {

        //  전체 리스트 (카테고리별 상위 5개)
        @Select("""
        SELECT v.id as variantId,
               f.slug as flavourSlug,
               f.name_ko as flavourNameKo,
               f.is_new as isNew,
               c.list_slug as categoryListSlug,
               c.name_ko as categoryNameKo,
               vm.url as imageUrl
        FROM product_variant v
        JOIN flavour f ON v.flavour_id = f.id
        JOIN category c ON v.category_id = c.id
        LEFT JOIN variant_media vm
               ON vm.variant_id = v.id AND vm.role = 'PACKSHOT'
        WHERE v.is_active = 1
        ORDER BY c.priority ASC, f.flavour_sort_rank ASC, f.name_ko ASC
        """)
        List<FlavourSummary> selectAllFlavours();


        /**
         * 카테고리 slug 존재 여부 확인
         * @param slug 카테고리 slug
         * @return 존재하면 1 이상, 없으면 0
         */
        @Select("""
        SELECT COUNT(*)
        FROM category
        WHERE list_slug = #{slug}
    """)
        int existsCategorySlug(String slug);


        //  특정 카테고리 전체 리스트
        @Select("""
        SELECT v.id as variantId,
               f.slug as flavourSlug,
               f.name_ko as flavourNameKo,
               f.is_new as isNew,
               f.flavour_type_id as flavourTypeId,
               c.list_slug as categoryListSlug,
               c.name_ko as categoryNameKo,
               vm.url as imageUrl
        FROM product_variant v
        JOIN flavour f ON v.flavour_id = f.id
        JOIN category c ON v.category_id = c.id
        LEFT JOIN variant_media vm
               ON vm.variant_id = v.id AND vm.role = 'PACKSHOT'
        WHERE v.is_active = 1
          AND c.list_slug = #{listSlug}
        ORDER BY (CASE WHEN f.is_new = 1 THEN 0 ELSE 1 END),
                 f.flavour_type_id ASC,
                 f.name_ko ASC
        """)
        List<FlavourSummary> selectByCategory(String listSlug);


        // variant 상세 (카테고리 지정)
        @Select("""
    SELECT v.id         AS variantId,
           f.id         AS flavourId,
           f.slug       AS flavourSlug,
           f.name_ko    AS flavourNameKo,
           f.description_ko AS flavourDescriptionKo,
           f.is_new     AS isNew,
           c.slug       AS categorySlug,
           c.list_slug  AS categoryListSlug,
           c.name_ko    AS categoryNameKo
    FROM product_variant v
    JOIN flavour f ON v.flavour_id = f.id
    JOIN category c ON v.category_id = c.id
    WHERE v.is_active = 1
      AND f.slug = #{flavourSlug}
      AND c.slug = #{categorySlug}
    """)
        VariantDetail selectVariantDetail(@Param("flavourSlug") String flavourSlug,
                                          @Param("categorySlug") String categorySlug);



        // variant 상세 (카테고리 없이 flavourSlug만 들어왔을 때 기본 우선순위: PINT > MINI_CUP > SCOOP)
        @Select("""
    SELECT v.id         AS variantId,
           f.id         AS flavourId,
           f.slug       AS flavourSlug,
           f.name_ko    AS flavourNameKo,
           f.description_ko AS flavourDescriptionKo,
           f.is_new     AS isNew,
           c.slug       AS categorySlug,
           c.list_slug  AS categoryListSlug,
           c.name_ko    AS categoryNameKo
    FROM product_variant v
    JOIN flavour f ON v.flavour_id = f.id
    JOIN category c ON v.category_id = c.id
    WHERE v.is_active = 1
      AND f.slug = #{flavourSlug}
    ORDER BY c.priority ASC
    LIMIT 1
    """)
        VariantDetail selectVariantDetailDefault(@Param("flavourSlug") String flavourSlug);



        // 같은 flavour 가 가진 모든 카테고리 목록 조회
        @Select("""
            SELECT c.code,
                   c.slug       AS slug,
                   c.name_ko    AS nameKo,
                   v.id         AS variantId
            FROM product_variant v
            JOIN category c ON v.category_id = c.id
            WHERE v.flavour_id = #{flavourId}
              AND v.is_active = 1
            ORDER BY c.priority
            """)
        List<VariantDetail.AvailableCategory> selectAvailableCategories(Long flavourId);




        //  미디어
        @Select("""
        SELECT role, url, alt_ko as altKo
        FROM variant_media
        WHERE variant_id = #{variantId}
        ORDER BY role, sort_order
        """)
        List<VariantDetail.Media> selectVariantMedia(Long variantId);


        //  원재료
        @Select("""
        SELECT ingredients_ko as ingredientsKo,
               smartlabel_url as smartlabelUrl
        FROM variant_ingredients
        WHERE variant_id = #{variantId}
        """)
        VariantDetail.Ingredients selectVariantIngredients(Long variantId);


        //  배지 - sourcing
        @Select("""
        SELECT sf.name_ko as nameKo, sf.icon_url as iconUrl
        FROM variant_sourcing vs
        JOIN sourcing_feature sf ON vs.feature_id = sf.id
        WHERE vs.variant_id = #{variantId}
        ORDER BY vs.sort_order
        """)
        List<VariantDetail.SourcingFeature> selectVariantSourcing(Long variantId);


        //  배지 - dietary
        @Select("""
        SELECT dc.name_ko as nameKo, dc.icon_url as iconUrl
        FROM variant_cert vc
        JOIN dietary_cert dc ON vc.cert_id = dc.id
        WHERE vc.variant_id = #{variantId}
        ORDER BY vc.sort_order
        """)
        List<VariantDetail.DietaryCert> selectVariantCerts(Long variantId);


        //  추천
        @Select("""
        SELECT v.id as variantId,
               f.slug as flavourSlug,
               f.name_ko as flavourNameKo,
               f.is_new as isNew,
               c.slug as categorySlug,
               c.list_slug as categoryListSlug,
               c.name_ko as categoryNameKo,
               vm.url as imageUrl
        FROM variant_reco r
        JOIN product_variant v ON r.target_variant_id = v.id
        JOIN flavour f ON v.flavour_id = f.id
        JOIN category c ON v.category_id = c.id
        LEFT JOIN variant_media vm
               ON vm.variant_id = v.id AND vm.role = 'PACKSHOT'
        WHERE r.source_variant_id = #{variantId}
        ORDER BY r.slot
        """)
        List<FlavourSummary> selectRecommendations(Long variantId);


        //  navigation: 다음 variant
        @Select("""
        SELECT v.id as variantId,
               f.slug as flavourSlug,
               c.slug as categorySlug
        FROM product_variant v
        JOIN flavour f ON v.flavour_id = f.id
        JOIN category c ON v.category_id = c.id
        WHERE v.is_active = 1
          AND (
            (c.priority > (SELECT c2.priority
                           FROM product_variant pv2
                           JOIN flavour f2 ON pv2.flavour_id = f2.id
                           JOIN category c2 ON pv2.category_id = c2.id
                           WHERE pv2.id = #{variantId}))
            OR (
              c.priority = (SELECT c2.priority
                            FROM product_variant pv2
                            JOIN flavour f2 ON pv2.flavour_id = f2.id
                            JOIN category c2 ON pv2.category_id = c2.id
                            WHERE pv2.id = #{variantId})
              AND f.flavour_type_id > (SELECT f2.flavour_type_id
                                       FROM product_variant pv2
                                       JOIN flavour f2 ON pv2.flavour_id = f2.id
                                       WHERE pv2.id = #{variantId})
            )
            OR (
              c.priority = (SELECT c2.priority
                            FROM product_variant pv2
                            JOIN flavour f2 ON pv2.flavour_id = f2.id
                            JOIN category c2 ON pv2.category_id = c2.id
                            WHERE pv2.id = #{variantId})
              AND f.flavour_type_id = (SELECT f2.flavour_type_id
                                       FROM product_variant pv2
                                       JOIN flavour f2 ON pv2.flavour_id = f2.id
                                       WHERE pv2.id = #{variantId})
              AND f.name_ko > (SELECT f2.name_ko
                               FROM product_variant pv2
                               JOIN flavour f2 ON pv2.flavour_id = f2.id
                               WHERE pv2.id = #{variantId})
            )
          )
        ORDER BY c.priority ASC, f.flavour_type_id ASC, f.name_ko ASC
        LIMIT 1
        """)
        VariantNavigation findNextVariant(Long variantId);


        //  navigation: 첫 variant (마지막일 경우 순환)
        @Select("""
        SELECT v.id as variantId,
               f.slug as flavourSlug,
               c.slug as categorySlug
        FROM product_variant v
        JOIN flavour f ON v.flavour_id = f.id
        JOIN category c ON v.category_id = c.id
        WHERE v.is_active = 1
        ORDER BY c.priority ASC, f.flavour_type_id ASC, f.name_ko ASC
        LIMIT 1
        """)
        VariantNavigation findFirstVariant();
}
