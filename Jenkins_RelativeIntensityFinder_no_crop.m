function g = RelativeIntensityFinder_FINAL(A)
        %%% The following code is a test for relative differences in pixel
        %%% intensity value to neighboring cells at a percent difference
        %%% listed below as the percent difference filter.
        
        percentDifference = 0.01;
       
        %%% K VALUE
        %%% The grey filter is a filter on a scale of 0-255 that can be
        %%% adjusted based upon what whites are let through. 
        K = 150;            
        greyFilter = A < K;
        A(greyFilter) = 0;
        %%% m and n are one less than the length in pixels of the X and Y dimensions of
        %%% the SEM image: m = X-1, n = Y-1
             for m = 2:1023
            for n = 2:1023
                if abs((A(m,n)-A(m-1,n-1)/A(m,n))) >= percentDifference & ...
                   abs((A(m,n)-A(m-1,n)/A(m,n))) >= percentDifference   & ...
                   abs((A(m,n)-A(m-1,n+1)/A(m,n))) >= percentDifference & ...
                   abs((A(m,n)-A(m,n-1)/A(m,n))) >= percentDifference   & ...
                   abs((A(m,n)-A(m,n+1)/A(m,n))) >= percentDifference   & ...
                   abs((A(m,n)-A(m+1,n-1)/A(m,n))) >= percentDifference & ...
                   abs((A(m,n)-A(m+1,n)/A(m,n))) >= percentDifference   & ...
                   abs((A(m,n)-A(m+1,n+1)/A(m,n))) >= percentDifference 
                   
                   A(m,n) = A(m,n);
                
                else
                   A(m,n) = 0;
                end
                
            end
        end
        g = A;

end