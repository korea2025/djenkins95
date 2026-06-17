function [X,Average_Pore_diameter,Standard_Deviation_of_Pore_diameter] = PoreSizeCalculator_FINAL(File_Name, scaleBar)

N=15; 

A = imread(File_Name);

%%% Insert total pixel length X and height Y of your image here "(A,[0, 0 , X, Y])"
A = imcrop(A,[0, 0, 1024, 1024]);
A = RelativeIntensityFinder_FINAL(A);

%     Q =imread(File_Name);
%     fprintf('Crop image around scale bar and double click to select cropped area. \n\n');
%     Q = imcrop(Q);
%     binaryB = Q==185;
%     s = sum(binaryB, 2);
    
    %%% micron/pixel this is the spatial 
    %%%resolution of the input, sets the scale bar to pixel size ratio.
Resolution= scaleBar;

%%% The following if statement makes the adjustment from colored files to
%%% gray scale files.
if ndims(A)==3 
B=rgb2gray(A);
else
B = A;
end

%%% The following data uses the intensity value provided to correct for how
%%% bright the image should be and can cast away SOME (not all) of any
%%% bright inconsistencies with a bad image.
level = multithresh(B,N);
C= imquantize(B,level);
RGB1 = label2rgb(B);

%%% CHANGE file type if using type other than "tiff" images
%CHANGE the "X" in "fileName(1:end-X)" if you are using a file type
imwrite(RGB1,[File_Name(1:end-4) '_Depth Map.tiff']);

%%%This runs in conjunction with the relativeIntensityFinder file to
%%%help determine what is determined as black and what is determined as
%%%white for pore sizes and such.
P=zeros(size(C));
for I=1:size(C,1)
    for J=1:size(C,2)
        if C(I,J)==1
            P(I,J)=1;
        end
    end
end
P=1-P;
P=bwmorph(P,'majority',1);

%%% CHANGE file type if using type other than "tiff" images
%%% CHANGE the "X" in "fileName(1:end-X)" if you are using a file type
imwrite(P,[File_Name(1:end-4) '_Binary Segmentation.tiff']);

%%% The second number in the imgaussfilt is the standarddeviation to use to split up
%%% pore sizes. The smaller it is the more pores there will be, the larger
%%% it is the more willing it is to disregard flaws and accept a pore with
%%% background noise as 1 pore.
Conn=8;
[s1,s2]=size(P);
D=-bwdist(P,'quasi-euclidean');
B=imgaussfilt(B,15);

%%%Determines where the script calculates pores and non-pores in an image and
%%%determines what is 1 pore and what is two pores with a tear 
B=watershed(B,Conn);
Pr=zeros(s1,s2);

for I=1:s1
    for J=1:s2
        if P(I,J)==0 && B(I,J)~=0
            Pr(I,J)=1;
        end
    end
end
Pr=bwareaopen(Pr,9,Conn);

%%% The following code uses the watershed function to create an image that
%%% is color coded(each color next to each other should be different) to
%%% show what is a unique pore being detected and where all that area that
%%% is colored would drain to.
[Pr_L,Pr_n]=bwlabel(Pr,Conn);
RGB2 = label2rgb(Pr_L,'jet','white','shuffle');

%%% CHANGE file type if using type other than "tiff" images
%%% CHANGE the "X" in "fileName(1:end-X)" if you are using a file type
imwrite(RGB2,[File_Name(1:end-4) '_Pore Space Segmentation.tiff']);

%%% The following code determines the maximum pore diameter of a pore and
%%% creates a vector storing all the maximum values of these pores.
V=zeros(Pr_n,1);
for I=1:s1
    for J=1:s2
        if Pr_L(I,J)~=0
            V(Pr_L(I,J))=V(Pr_L(I,J))+1;
        end
    end
end
%%% The following code determines the actual maximum pore size
%%% visualized in an image;
X=Resolution.*(V./pi).^.5*2; 
X=sort(X);
disp(X);
prompt = 'Input minimum pore size. \n\n';
minPore = input(prompt); 
fprintf('\n'); 
X = X(X>minPore);
prompt = 'Input maximum pore size. \n\n'; 
maxPore = input(prompt); 
fprintf('\n'); 
X = X(X<maxPore);


%%% This determines the standard deviation of the maximum pore sizes in microns 
%%% within an image.
Average_Pore_diameter=mean(X) 
%%% micron scale
%%% This creates a graph with the original image, the intensity map, the
%%% black and white determination, and what is determined to be pores all on
%%% the same matlab figure. Each of these images is saved for reference
%%% later, but if it wanted to viewing during analysis, add a stop on the
%%% file loop in PoreCalculator.
Standard_Deviation_of_Pore_diameter=std(X) 
figure; 
subplot(2,3,1); imshow(A); title('Original SEM Image');
subplot(2,3,2); imshow(RGB1); title('Depth Map');
subplot(2,3,3); imshow(P); title('Binary Segmentation');
subplot(2,3,4); imshow(RGB2); title('Pore Space Segmentation');
subplot(2,3,5:6); hist(X,25); xlabel('Pore Diameter (um)'); ylabel('Frequency'); title('Pore Size Distribution');
set(gcf, 'Position' , get(0, 'Screensize' ));
end
