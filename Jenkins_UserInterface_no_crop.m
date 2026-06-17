clc; clear all; close all;

%%% CHANGE file type if using type other than "tiff" images
selpath = uigetdir(pwd, 'Select a Folder containing only .tiff files.'); 
files = dir(fullfile(selpath, '*.tiff')); 
newPath = addpath(selpath, '-begin'); 

prompt = 'Is the scale bar the same size for all images? [yes/no] \n\n'; 
str = input(prompt,'s'); 
fprintf('\n'); 

%%% checks if user input is one of the accepted replies and loops until reply is "yes"
while 1 
    if  strcmp(str,"yes") || strcmp(str,'y') || strcmp(str,'Y') || strcmp(str,"Yes")
        break
    elseif strcmp(str,"no") || strcmp(str,'n') || strcmp(str,'N') || strcmp(str,"No")
        fprintf('Please make folder containing images with same scale bar size. \n\n');
        return
    else
        prompt = 'Please input yes/no. \n\n';
        str = input(prompt,'s');
        fprintf('\n');
    end
end

prompt = 'What is the scale bar size for all images? [um] \n\n'; 
scale = input(prompt); 
fprintf('\n');

prompt = 'What is the length of the scale bar? [pixel] \n\n'; 
pixel = input(prompt)
fprintf('\n'); 

Resolution= scale/pixel;

here = mfilename('fullpath'); 
[myPath, ~, ~] = fileparts(here); 
[rows, ~] = size(files); 
for i = 1:rows 
    fileName = files(i).name; 
   
    %%% Runs porosity calculator taken and adapted from Arash Rabbani            
    [allPores, avgPoreDiameter, stdDevPore] = PoreSizeCalculator_FINAL(fileName, Resolution); 
   
    %%% Creates a table with all the desired excel data
    excelFileData.allPores = allPores; 
    excelFileData.avgPoreDiameter = avgPoreDiameter;
    excelFileData.stdDevPore = stdDevPore;

    [numberOfPores] = size(excelFileData.allPores,1);
                
    if size(excelFileData.avgPoreDiameter,1) < numberOfPores
        numberOfZeros = zeros(numberOfPores-size(excelFileData.avgPoreDiameter,1),1);
        excelFileData.avgPoreDiameter = [excelFileData.avgPoreDiameter; numberOfZeros];
    end
    if size(excelFileData.stdDevPore,1) < numberOfPores
        numberOfZeros = zeros(numberOfPores-size(excelFileData.stdDevPore,1),1);
        excelFileData.stdDevPore = [excelFileData.stdDevPore; numberOfZeros];
    end
    
     %%% Creates a table in Excel that can be used for data analysis, includes Standard Deviation, Mean, and Raw Data 
     %%% CHANGE the "X" in "fileName(1:end-X)" if you are using a file type
     %%% with a different name length (eg. tiff: X=4, tif: X=3)
    writetable(struct2table(excelFileData), [fileName(1:end-4), 'xlsx'], 'WriteRowNames', true);
end

%%% CHANGE file type if using type other than "tiff" images
movefile('*.tiff', selpath); 

%%% Moves the excel files to the data folder
movefile('*.xlsx', selpath);
    
