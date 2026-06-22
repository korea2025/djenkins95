%% Jenkins_SurfacePitting_SpatialAnalysis.m
% SEM Surface Pitting Feature Quantification + Spatial Inference
% 기존 Jenkins 방식 유지:
% - Relative intensity filtering
% - multithresh segmentation
% - watershed separation
% - ECD calculation
%
% 추가 기능:
% - Object centroid extraction
% - Inter-pit distance
% - Nearest-neighbor distance
% - Edge-to-edge approximate distance
% - Spatial density
% - Clustering index
% - Feature-level Excel output
% - Image-level summary Excel output
% - Annotated image output

clc; clear; close all;

%% ================= USER INPUT =================

selpath = uigetdir(pwd, 'Select folder containing SEM image files');
if selpath == 0
    error('No folder selected.');
end

files = [dir(fullfile(selpath, '*.tif')); ...
         dir(fullfile(selpath, '*.tiff')); ...
         dir(fullfile(selpath, '*.png')); ...
         dir(fullfile(selpath, '*.jpg')); ...
         dir(fullfile(selpath, '*.jpeg'))];

if isempty(files)
    error('No image files found in selected folder.');
end

scale_um = input('What is the scale bar size? [um] : ');
scale_px = input('What is the scale bar length? [pixel] : ');
Resolution = scale_um / scale_px;   % um/pixel

minPitECD = input('Input minimum pit-equivalent diameter [um] : ');
maxPitECD = input('Input maximum pit-equivalent diameter [um] : ');

cropChoice = input('Crop image? [yes/no] : ', 's');

outDir = fullfile(selpath, 'SurfacePitting_Spatial_Results');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

summaryAll = table();

%% ================= BATCH PROCESSING =================

for k = 1:numel(files)

    fileName = files(k).name;
    filePath = fullfile(selpath, fileName);
    [~, baseName, ~] = fileparts(fileName);

    fprintf('\nProcessing image: %s\n', fileName);

    A0 = imread(filePath);

    %% -------- Crop Option --------
    if strcmpi(cropChoice, 'yes') || strcmpi(cropChoice, 'y')
        figure; imshow(A0);
        title('Select analysis region, then double click');
        A0 = imcrop(A0);
        close;
    else
        % 원본 Jenkins 코드가 1024 x 1024 기준이므로,
        % 이미지가 충분히 크면 좌상단 1024 x 1024로 분석
        [h0, w0, ~] = size(A0);
        if h0 >= 1024 && w0 >= 1024
            A0 = imcrop(A0, [0, 0, 1024, 1024]);
        end
    end

    %% -------- Convert to Grayscale --------
    if ndims(A0) == 3
        Agray = rgb2gray(A0);
    else
        Agray = A0;
    end

    Agray = im2uint8(Agray);

    %% =====================================================
    %  1. RELATIVE INTENSITY FILTER
    %  기존 RelativeIntensityFinder_FINAL 기능 내장
    %% =====================================================

    Arel = localRelativeIntensityFinder(Agray);

    %% -------- Multilevel Thresholding --------
    N = 15;
    level = multithresh(Arel, N);
    C = imquantize(Arel, level);

    RGB_intensity = label2rgb(Arel);
    imwrite(RGB_intensity, fullfile(outDir, [baseName '_RelativeIntensityMap_notDepth.tif']));

    %% -------- Binary Segmentation --------
    P = zeros(size(C));

    for i = 1:size(C,1)
        for j = 1:size(C,2)
            if C(i,j) == 1
                P(i,j) = 1;
            end
        end
    end

    P = 1 - P;
    P = bwmorph(P, 'majority', 1);

    imwrite(P, fullfile(outDir, [baseName '_BinarySegmentation.tif']));

    %% =====================================================
    %  2. WATERSHED SEPARATION
    %% =====================================================

    Conn = 8;
    [s1, s2] = size(P);

    Bsmooth = imgaussfilt(Arel, 15);
    Bwater = watershed(Bsmooth, Conn);

    Pr = zeros(s1, s2);

    for i = 1:s1
        for j = 1:s2
            if P(i,j) == 0 && Bwater(i,j) ~= 0
                Pr(i,j) = 1;
            end
        end
    end

    Pr = bwareaopen(Pr, 9, Conn);

    %% -------- Label Surface Pitting Features --------
    [Pr_L, Pr_n] = bwlabel(Pr, Conn);

    %% =====================================================
    %  3. OBJECT MEASUREMENT
    %% =====================================================

    stats = regionprops(Pr_L, ...
        'Area', ...
        'Centroid', ...
        'Perimeter', ...
        'EquivDiameter', ...
        'MajorAxisLength', ...
        'MinorAxisLength', ...
        'Eccentricity', ...
        'Solidity', ...
        'Orientation');

    if isempty(stats)
        warning('No surface pitting features detected in %s', fileName);
        continue;
    end

    %% -------- Extract Raw Variables --------
    Area_px = [stats.Area]';
    ECD_um = [stats.EquivDiameter]' * Resolution;

    %% -------- Size Filtering --------
    valid = ECD_um >= minPitECD & ECD_um <= maxPitECD;

    validIDs = find(valid);
    Pr_filtered = ismember(Pr_L, validIDs);

    [Pr_L_filtered, Pr_n_filtered] = bwlabel(Pr_filtered, Conn);

    stats = regionprops(Pr_L_filtered, ...
        'Area', ...
        'Centroid', ...
        'Perimeter', ...
        'EquivDiameter', ...
        'MajorAxisLength', ...
        'MinorAxisLength', ...
        'Eccentricity', ...
        'Solidity', ...
        'Orientation');

    if isempty(stats)
        warning('No valid surface pitting features after filtering in %s', fileName);
        continue;
    end

    %% =====================================================
    %  4. FINAL FEATURE VARIABLES
    %% =====================================================

    FeatureID = (1:numel(stats))';

    Area_px = [stats.Area]';
    Area_um2 = Area_px * Resolution^2;

    ECD_um = [stats.EquivDiameter]' * Resolution;
    Radius_um = ECD_um / 2;

    Perimeter_um = [stats.Perimeter]' * Resolution;

    MajorAxis_um = [stats.MajorAxisLength]' * Resolution;
    MinorAxis_um = [stats.MinorAxisLength]' * Resolution;

    Eccentricity = [stats.Eccentricity]';
    Solidity = [stats.Solidity]';
    Orientation_deg = [stats.Orientation]';

    Centroids_px = cat(1, stats.Centroid);
    CentroidX_px = Centroids_px(:,1);
    CentroidY_px = Centroids_px(:,2);

    CentroidX_um = CentroidX_px * Resolution;
    CentroidY_um = CentroidY_px * Resolution;

    Circularity = 4*pi*Area_um2 ./ (Perimeter_um.^2);
    Circularity(isinf(Circularity)) = NaN;

    %% =====================================================
    %  5. SPATIAL DISTANCE VARIABLES
    %% =====================================================

    nF = numel(FeatureID);

    if nF >= 2

        dx = CentroidX_um - CentroidX_um';
        dy = CentroidY_um - CentroidY_um';

        InterPitDistanceMatrix_um = sqrt(dx.^2 + dy.^2);

        % 자기 자신과의 거리 제거
        InterPitDistanceMatrix_um(1:nF+1:end) = NaN;

        % 중심점 기준 최근접 이웃 거리
        NearestNeighborDistance_um = min(InterPitDistanceMatrix_um, [], 2, 'omitnan');

        % 객체 가장자리 간 근사 거리
        EdgeDistanceMatrix_um = InterPitDistanceMatrix_um - (Radius_um + Radius_um');
        EdgeDistanceMatrix_um(EdgeDistanceMatrix_um < 0) = 0;
        EdgeDistanceMatrix_um(1:nF+1:end) = NaN;

        NearestEdgeDistance_um = min(EdgeDistanceMatrix_um, [], 2, 'omitnan');

        Mean_InterPitDistance_um = mean(InterPitDistanceMatrix_um(:), 'omitnan');
        Median_InterPitDistance_um = median(InterPitDistanceMatrix_um(:), 'omitnan');

        Mean_NND_um = mean(NearestNeighborDistance_um, 'omitnan');
        Median_NND_um = median(NearestNeighborDistance_um, 'omitnan');

        Mean_NearestEdgeDistance_um = mean(NearestEdgeDistance_um, 'omitnan');

    else

        InterPitDistanceMatrix_um = NaN;
        EdgeDistanceMatrix_um = NaN;

        NearestNeighborDistance_um = NaN;
        NearestEdgeDistance_um = NaN;

        Mean_InterPitDistance_um = NaN;
        Median_InterPitDistance_um = NaN;

        Mean_NND_um = NaN;
        Median_NND_um = NaN;

        Mean_NearestEdgeDistance_um = NaN;
    end

    %% =====================================================
    %  6. SPATIAL DENSITY & CLUSTERING INDEX
    %% =====================================================

    [H, W] = size(Agray);
    ImageArea_um2 = H * W * Resolution^2;

    FeatureCount = nF;

    SpatialDensity_count_per_um2 = FeatureCount / ImageArea_um2;

    PitAreaFraction = sum(Area_um2) / ImageArea_um2;

    % 랜덤 분포일 때 기대 최근접거리 근사:
    % E[r] = 1 / (2 * sqrt(lambda))
    % lambda = density
    ExpectedRandomNND_um = 1 / (2 * sqrt(SpatialDensity_count_per_um2));

    % Clustering Index
    % CI < 1 : random보다 더 가까움 = 군집 경향
    % CI ≈ 1 : random 유사
    % CI > 1 : 분산 경향
    ClusteringIndex_NND = Mean_NND_um / ExpectedRandomNND_um;

    %% =====================================================
    %  7. FEATURE-LEVEL OUTPUT TABLE
    %% =====================================================

    featureTable = table( ...
        FeatureID, ...
        CentroidX_px, CentroidY_px, ...
        CentroidX_um, CentroidY_um, ...
        Area_px, Area_um2, ...
        ECD_um, Radius_um, Perimeter_um, ...
        Circularity, ...
        MajorAxis_um, MinorAxis_um, ...
        Eccentricity, Solidity, Orientation_deg, ...
        NearestNeighborDistance_um, ...
        NearestEdgeDistance_um);

    writetable(featureTable, fullfile(outDir, [baseName '_FeatureLevel_SurfacePitting.xlsx']));

    %% -------- Distance Matrix Output --------
    if nF >= 2
        writematrix(InterPitDistanceMatrix_um, ...
            fullfile(outDir, [baseName '_InterPitDistanceMatrix_um.xlsx']));

        writematrix(EdgeDistanceMatrix_um, ...
            fullfile(outDir, [baseName '_ApproxEdgeDistanceMatrix_um.xlsx']));
    end

    %% =====================================================
    %  8. IMAGE-LEVEL SUMMARY TABLE
    %% =====================================================

    Mean_ECD_um = mean(ECD_um, 'omitnan');
    Median_ECD_um = median(ECD_um, 'omitnan');
    SD_ECD_um = std(ECD_um, 'omitnan');
    Min_ECD_um = min(ECD_um);
    Max_ECD_um = max(ECD_um);

    Mean_Area_um2 = mean(Area_um2, 'omitnan');
    Mean_Circularity = mean(Circularity, 'omitnan');
    Mean_Solidity = mean(Solidity, 'omitnan');

    summaryTable = table( ...
        {fileName}, ...
        FeatureCount, ...
        ImageArea_um2, ...
        SpatialDensity_count_per_um2, ...
        PitAreaFraction, ...
        Mean_ECD_um, Median_ECD_um, SD_ECD_um, Min_ECD_um, Max_ECD_um, ...
        Mean_Area_um2, ...
        Mean_Circularity, Mean_Solidity, ...
        Mean_InterPitDistance_um, Median_InterPitDistance_um, ...
        Mean_NND_um, Median_NND_um, ...
        Mean_NearestEdgeDistance_um, ...
        ExpectedRandomNND_um, ...
        ClusteringIndex_NND, ...
        'VariableNames', { ...
        'ImageName', ...
        'FeatureCount', ...
        'ImageArea_um2', ...
        'SpatialDensity_count_per_um2', ...
        'PitAreaFraction', ...
        'Mean_ECD_um', 'Median_ECD_um', 'SD_ECD_um', 'Min_ECD_um', 'Max_ECD_um', ...
        'Mean_Area_um2', ...
        'Mean_Circularity', 'Mean_Solidity', ...
        'Mean_InterPitDistance_um', 'Median_InterPitDistance_um', ...
        'Mean_NearestNeighborDistance_um', 'Median_NearestNeighborDistance_um', ...
        'Mean_NearestEdgeDistance_um', ...
        'ExpectedRandomNND_um', ...
        'ClusteringIndex_NND'});

    summaryAll = [summaryAll; summaryTable];

    %% =====================================================
    %  9. VISUAL OUTPUTS
    %% =====================================================

    RGB_label = label2rgb(Pr_L_filtered, 'jet', 'white', 'shuffle');
    imwrite(RGB_label, fullfile(outDir, [baseName '_LabeledSurfacePittingFeatures.tif']));

    figure('Visible','off');
    imshow(Agray); hold on;
    visboundaries(Pr_L_filtered, 'Color', 'r');
    plot(CentroidX_px, CentroidY_px, 'b+', 'MarkerSize', 6, 'LineWidth', 1);

    for ii = 1:nF
        text(CentroidX_px(ii)+3, CentroidY_px(ii), num2str(ii), ...
            'Color', 'yellow', 'FontSize', 7);
    end

    title(['Detected Surface Pitting Features: ' fileName], 'Interpreter','none');
    saveas(gcf, fullfile(outDir, [baseName '_Annotated_Features_Centroids.tif']));
    close;

    figure('Visible','off');
    histogram(ECD_um, 25);
    xlabel('Pit-equivalent diameter, ECD (\mum)');
    ylabel('Frequency');
    title(['ECD Distribution: ' fileName], 'Interpreter','none');
    saveas(gcf, fullfile(outDir, [baseName '_ECD_Distribution.tif']));
    close;

    if nF >= 2
        figure('Visible','off');
        histogram(NearestNeighborDistance_um, 25);
        xlabel('Nearest-neighbor distance (\mum)');
        ylabel('Frequency');
        title(['Nearest-neighbor Distance Distribution: ' fileName], 'Interpreter','none');
        saveas(gcf, fullfile(outDir, [baseName '_NND_Distribution.tif']));
        close;
    end

    figure('Visible','off');
    imshow(Agray); hold on;
    plot(CentroidX_px, CentroidY_px, 'ro', 'MarkerSize', 4, 'LineWidth', 1);
    title(['Spatial Distribution of Surface Pitting Features: ' fileName], 'Interpreter','none');
    saveas(gcf, fullfile(outDir, [baseName '_SpatialDistribution.tif']));
    close;

    fprintf('Completed: %s\n', fileName);

end

%% ================= SAVE OVERALL SUMMARY =================

writetable(summaryAll, fullfile(outDir, 'All_Image_SurfacePitting_SpatialSummary.xlsx'));

fprintf('\nAll analyses completed.\n');
fprintf('Results saved in:\n%s\n', outDir);


%% =========================================================
% LOCAL FUNCTION
% Relative Intensity Finder
% 기존 RelativeIntensityFinder_FINAL 기능 내장
%% =========================================================

function g = localRelativeIntensityFinder(A)

    A = im2uint8(A);

    percentDifference = 0.01;
    K = 150;

    greyFilter = A < K;
    A(greyFilter) = 0;

    [rows, cols] = size(A);

    B = A;

    for m = 2:rows-1
        for n = 2:cols-1

            centerVal = double(A(m,n));

            if centerVal == 0
                B(m,n) = 0;
                continue;
            end

            neighbors = double([ ...
                A(m-1,n-1), A(m-1,n), A(m-1,n+1), ...
                A(m,n-1),               A(m,n+1), ...
                A(m+1,n-1), A(m+1,n), A(m+1,n+1)]);

            relativeDiff = abs(centerVal - neighbors) ./ centerVal;

            if all(relativeDiff >= percentDifference)
                B(m,n) = A(m,n);
            else
                B(m,n) = 0;
            end
        end
    end

    g = B;

end