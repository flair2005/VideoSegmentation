% Function that implements the Video Rapid Segment algorithm
%
%    Copyright (C) 2013  Anestis Papazoglou
%
%    You can redistribute and/or modify this software for non-commercial use
%    under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%    For commercial use, contact the author for licensing options.
%
%    Contact: a.papazoglou@sms.ed.ac.uk

function segmentation = videoRapidSegment( options, params, data)
    
    % Params parsing
    if( ~isfield( params, 'locationWeight1' ) || ...
        isempty( params.locationWeight1 ) )
        params.locationWeight = 50;
    end
    
    if( ~isfield( params, 'spatialWeight' ) || ...
        isempty( params.spatialWeight ) )
        params.spatialWeight = 5000;
    end
    
    if( ~isfield( params, 'temporalWeight' ) || ...
        isempty( params.temporalWeight ) )
        params.temporalWeight = 4000;
    end
    
    if( ~isfield( params, 'fadeout' ) || isempty( params.fadeout ) )
        params.fadeout = 0.0001;
    end
    
    if( ~isfield( params, 'maxIterations' ) || ...
        isempty( params.maxIterations ) )
        params.maxIterations = 4;
    end
    
    if( isfield( params, 'foregroundMixtures' ) && ...
        ~isempty( params.foregroundMixtures ) )
        fgMix = params.foregroundMixtures;
    else
        fgMix = 5;
    end
    
    if( isfield( params, 'backgroundMixtures' ) && ...
        ~isempty( params.backgroundMixtures ) )
        bgMix = params.backgroundMixtures;
    else
        bgMix = 8;
    end
   % ���ϲ���������getDefaultParams������
   
    if( isfield( params, 'locationNorm' ) && ...
        ~isempty( params.locationNorm ) )
        locationNorm = params.locationNorm;
    else
        locationNorm = 0.75;
    end
    
    if( ~isfield( options, 'visualise' ) || isempty( options.visualise ) )
        options.visualise = false;
    end
    
    if( ~isfield( options, 'vocal' ) || isempty( options.vocal ) )
        options.vocal = false;
    end
    % End of params parsing
    
    flow = data.flow;
    superpixels = data.superpixels;
    
    % Compute inside-outside maps  ��3.1��
    if( options.vocal ), tic; fprintf( 'videoRapidSegment: Computing inside-outside maps...\t' ); end
     % data.edgePoints: �߽� (logical)
    [data.inMaps, data.edgePoints] = getInOutMaps( flow );    % data.inMaps�� 13 x 1 cell  (logical) ֻ���ڲ���ȥ���˱�
    inRatios = getSuperpixelInRatio( superpixels, data.inMaps );  % ����ռ�����ؿ�ı���
   %
%     data.inMaps = sun_inMaps(inRatios, superpixels, data.inMaps);  % �޸�
%     inRatios = getSuperpixelInRatio( superpixels, data.inMaps );
   %
    if( options.vocal ), toc; end
    
    imgs = data.imgs;
    frames = length( flow );
    
   
    % ����14 x 1 cell�ĳ����ؿ�ͳһ��š� labels�� һ�� double �������������
    % nodeFrameId:�������������ؿ��ܵĸ��� x 1
    [ superpixels, nodeFrameId, bounds, labels ] = ...  
        makeSuperpixelIndexUnique( superpixels );

    % �õ����г����ؿ��ƽ����ɫ����ɫ������������
    % colours��single�����������������ؿ��ܵĸ��� x 3
    % centres��single�����������������ؿ��ܵĸ��� x 2
    [ colours, centres, area] = ...
        getSuperpixelStats( imgs, superpixels, labels );
      sun_colours  = colours;
      
    % ��Ԫ��
    
   
    colours = uint8( round( colours ) );
    
    % Preallocate space for unary potentials
    nodes = size( colours, 1 );
    unaryPotentials = zeros( nodes, 2 );

    % Create location priors   
    if( options.vocal ), tic; fprintf( 'videoRapidSegment: Computing location priors...\t\t' ); end
    % ����L����ǰ������������飬�������ƶ�
    [ anyvalue, accumulatedInRatios ] = accumulateInOutMap( params, data );  % ��ǰ��������꣬�ó�ÿ�������ؿ���ۻ����ƶ�
    locationMasks = cell2mat( accumulatedInRatios );  % ǰ13֡��δ��׼����λ�����ܣ���������Ŀ��ĳ̶�
    
    locationUnaries = 0.5 * ones( nodes, 2, 'single' );

    locationUnaries( 1: length( locationMasks ), 1 ) = ... %% 
        locationMasks / ( locationNorm * max( locationMasks ) );  % ��׼��
    locationUnaries( locationUnaries > 0.95 ) = 0.999;  
    
    for( frame = 1: frames )% ��ÿһ֡�е�λ�����ܣ����е���
        start = bounds( frame );
        stop = bounds( frame + 1 ) - 1;
        
        frameMasks = locationUnaries( start: stop, 1 );
        overThres = sum( frameMasks > 0.6 ) / single( ( stop - start + 1) );

        if( overThres < 0.05 )
            E = 0.005;
        else
            E = 0.000;
        end
        locationUnaries( start: stop, 1 ) = ...
            max( locationUnaries( start: stop, 1 ), E );
        
    end
    locationUnaries( :, 2 ) = 1 - locationUnaries( :, 1 );
    
    if( options.vocal ), toc; end
    % λ��������ϣ�ֻ��ǰ13֡�����һ֡ ��1����2��Ϊ0.5����һ�б�������Ŀ��Զ���� �������ϴ�
    
    masks = 0.19 * ones( nodes, 1 );
    % inRatios: cell  13 x 1;һ��cell�е���Ϊÿ�������ؿ�ռ�ڲ�ͼ�ı���
%     masks( 1: bounds( frames + 1 ) - 1 ) = single( cell2mat( inRatios ) );
        % �޸�
        masks( 1: bounds( frames + 1 ) - 1 ) = single( cell2mat( inRatios ) );

    % Create binary masks for foreground/background initialisation
    foregroundMasks = masks > 0.2;  % ��ռ�ڲ�ͼ�ı������õ��������ǰ����ǩ(�ָ�) (19705 x 1)   firstSeg.jpg
    backgroundMasks = masks < 0.05; % ���һ֡�Ȳ���ǰ����Ҳ���Ǳ��� 0.19
    
    % �޸�
%     [totalInSegments, totalExSegments] = sun_getTotalInExsegments(locationUnaries, superpixels, data.edgePoints, 0.55, 0.7);
%     foregroundMasks([totalInSegments, totalExSegments]) = 0;  backgroundMasks([totalInSegments, totalExSegments]) = 0;
    %
    
    % Create fading frame weight
    if( options.vocal ), tic; fprintf( 'videoRapidSegment: Neighbour frame weighting...\t\t' ); end
    weights = zeros( 1 + 2 * frames, 1, 'single' );
    middle = frames + 1;
    for( i = 1: length( weights ) )
        weights( i ) = exp( - params.fadeout * ( i - middle ) ^ 2 );  % 27 x 1
    end
    if( options.vocal ), toc; end

   
    fgColors = colours( foregroundMasks, : );
    bgColors = colours( backgroundMasks, : );
    
    % �޸�
    potentialMatrix.appearance = zeros( nodes, 2 );
    potentialMatrix.location = zeros( nodes, 2 );
    potentialMatrix.LA = zeros( nodes, 2 );

    %
    for ( frame = 1: frames )
        
        ids = nodeFrameId - frame + middle;
        
        fgNodeWeights = masks( foregroundMasks ) .* ...
            weights( ids( foregroundMasks ) );   % ����ǰ����  ռ�ڲ�ͼ�ı��� x Զ��
        bgNodeWeights = ( 1 - masks( backgroundMasks ) ) .* ...
            weights( ids( backgroundMasks ) );

        [ uniqueFgColours, fgNodeWeights ] = ...
            findUniqueColourWeights( fgColors, fgNodeWeights );  %%%%  ???
        [ uniqueBgColours, bgNodeWeights ] = ...
            findUniqueColourWeights( bgColors, bgNodeWeights );
        
        startIndex = bounds( frame );
        stopIndex = bounds( frame + 1 ) - 1;
        
        if( size( uniqueFgColours, 1 ) < fgMix || ...
            size( uniqueBgColours, 1 ) < bgMix )  
        % ��ǰ�����߱�������̫�٣��޷�����GMM���򵥽ڵ�����ͳһȡ -log(0.5)
            warning( 'Too few data points to fit GMM...\n' ); %#ok<WNTAG>
            unaryPotentials( startIndex: stopIndex, : ) = -log( 0.5 );
        else
            % ѵ����֡��ǰ��ģ�ͺͼ���ڵ�ĸ����ܶȣ���Ҫ�õ�������Ƶ�����Ϣ
            [ fgModel ] = fitGMM( fgMix, uniqueFgColours, fgNodeWeights );
                  % fgMix ǰ����ϸ�˹ģ���У�����˹ģ�͵ĸ���
                  % fgNodeWeights �ɾ���Զ���� r ���������Ȩ��
            [ bgModel ] = fitGMM( bgMix, uniqueBgColours, bgNodeWeights );

            appearanceUnary = getUnaryAppearance( single( colours( nodeFrameId == frame, : ) ), fgModel, bgModel );
                % ��Ϊ�����㣬����ת��Ϊsingle��float������
                % appearanceUnary   ��С����֡�Ľڵ��� x 2��ÿ���ڵ���� ��ǰ���ͱ����Ŀ�����
                
                % �޸�
%                 appearanceUnaryMatrix = [appearanceUnaryMatrix; appearanceUnary ];
                % 
                
                tempLocationUnaries = locationUnaries( startIndex: stopIndex, : );
%                 tempLocationUnaries(tempLocationUnaries == 0, 1) = min(tempLocationUnaries(tempLocationUnaries(:,1)  ~= 0, 1));
%                   tempLocationUnaries = locationUnaries(startIndex: stopIndex, :);

                laUnary = sun_getUnaryLA(double(tempLocationUnaries), appearanceUnary);
                
                % �ۼ� potentialMatrix
               potentialMatrix.appearance( startIndex: stopIndex, :) = appearanceUnary;
               potentialMatrix.location( startIndex: stopIndex, :) = tempLocationUnaries;
                potentialMatrix.LA( startIndex: stopIndex, :) = laUnary ;
           
            unaryPotentials( startIndex: stopIndex, : ) = -params.locationWeight1 * log(tempLocationUnaries ) + ...
                -params.appearanceWeight1*log( appearanceUnary )+...
                -params.laWeight1*log( laUnary );
            % locationUnaries ��С������֡�Ľڵ��� x 2 ��ÿ�ж��о����ֵ��
            % ��һ�б����ýڵ����ڲ�ͼ�������ԣ����Ǳ���+���²��֣����ڶ���Ϊ��1 - ��һ����ֵ
            % unaryPotentials��ֻ��13֡.���һ֡��unaryPotentialֻ�� 0 0
        end
    end
    
       % ����ǰ������
 potentialMatrix.appearance = -log(potentialMatrix.appearance);
 potentialMatrix.location= -log(potentialMatrix.location);
 potentialMatrix.LA = -log(potentialMatrix.LA);
 appearance = mapBelief( potentialMatrix.appearance ); location = mapBelief( potentialMatrix.location );  LA = mapBelief(  potentialMatrix.LA  );
 
  foreground = appearance./maxmax(appearance) >= 0 |  location./maxmax(location) >= 0  |  LA./maxmax( LA ) >= 0;
     
    
    
    
     % �޸�
%     [consInSegments, consExSegments] = sun_edgeConstraints(appearanceUnaryMatrix, superpixels, locationUnaries, data, 0.2, 0.3);
%     pairPotentials = sun_updatePairwisePotentials (params, pairPotentials, consInSegments, consExSegments);
    
 % Compute pairwise potentials
    if( options.vocal ),  fprintf( 'videoRapidSegment: Computing pairwise potentials: \n' ); end
%     pairPotentials = computePairwisePotentials( params, superpixels, ...
%         flow, colours, centres, labels );
    [pairPotentials, vNumbers]= sun_computeTernaryPotentials(  options,params, superpixels, flow, sun_colours,...
      centres, labels ,bounds, nodeFrameId, potentialMatrix, data);
  potentialMatrix = [];  
  
  % ���� unaryPotentials���ֳ�����ǰ������
  unaryPotentials( ~foreground, 1) = inf;  % ������  -log(5e-100)*30
  unaryPotentials( ~foreground, 2) = eps ;  %  -log(1-5e-100)*30 
  unaryPotentials(bounds(end-1):bounds(end)-1, : ) = 0;
  
   % Initialise segmentations
    if( options.vocal ), tic; fprintf( 'videoRapidSegment: Computing initial segmentation...\t' ); end
    [ anyvalue, labels ] = maxflow_mex_optimisedWrapper( pairPotentials, ...
        single( unaryPotentials ) );   % ��ʼ���ָ Ϊʲô���ڵ����ܻ�Ҫ����10��

    segmentation = superpixelToPixel( labels, superpixels ); %%%%%%%%% ��ɾ
       % ���룺����Ψһ������ labels �� superpixels
    if( options.vocal ), toc; end
    
    % Check that we did not get a trivial, all-background/foreground
    % segmentation
    if( all( labels ) || all( ~labels ) )
        if( options.vocal ), fprintf( 'videoRapidSegment: Trivial segmentation detected, exiting...\n' ); end
        return;
    end
    
    sun_oldLabels = labels;
    % Iterating segmentations
    for( i = 2: params.maxIterations )
        if( options.vocal ), tic; fprintf( 'videoRapidSegment: Iteration: %d...\t\t\t\n', i ); end
        
        fgColors = colours( labels, : ); 
        % ��������ȡֵ�����ࣺ
        % 1.����Ϊ�߼�ֵ0/1����������£�ֻȡ�߼�ֵΪ 1 ��ֵ��
        % 2. ����Ϊ��ţ�ȡ��Ӧ��ŵ�ֵ 
        
        bgColors = colours( ~labels, : );
            oldLabels = labels;
            
      % �޸�
    potentialMatrix.appearance = zeros( nodes, 2 );
    potentialMatrix.location = zeros( nodes, 2 );
    potentialMatrix.LA = zeros( nodes, 2 );
        for( frame = 1: frames )
            ids = nodeFrameId - frame + middle;

            fgNodeWeights = weights( ids( labels ) );  % ����ǰ����Ȩ��ֵ��Զ���й�
            bgNodeWeights = weights( ids( ~labels ) );

            [ uniqueFgColours, fgNodeWeights ] = ...
                findUniqueColourWeights( fgColors, fgNodeWeights );
            [ uniqueBgColours, bgNodeWeights ] = ...
                findUniqueColourWeights( bgColors, bgNodeWeights );

            if( size( uniqueFgColours, 1 ) < fgMix || ...
                size( uniqueBgColours, 1 ) < bgMix )
                warning( 'videoRapidSegment: Too few data points to fit GMM...\n' ); %#ok<WNTAG>
                return;
            end
            
            [ fgModel ] = fitGMM( fgMix, uniqueFgColours, fgNodeWeights );  % fgModel:��ϸ�˹ģ�͵Ĳ���
            [ bgModel ] = fitGMM( bgMix, uniqueBgColours, bgNodeWeights );
            
            appearanceUnary = getUnaryAppearance( ...
                single( colours( nodeFrameId == frame, : ) ), ...
                fgModel, bgModel );
            % �õ����ģ�ͣ�ÿ֡�ڵ���� x 2(����fg bg) 1:13

            startIndex = bounds( frame );
            stopIndex = bounds( frame + 1 ) - 1;

            % �޸�
               tempLocationUnaries = locationUnaries( startIndex: stopIndex, : );
%                 tempLocationUnaries(tempLocationUnaries == 0, 1) = min(tempLocationUnaries(tempLocationUnaries(:,1)  ~= 0, 1));
%                   tempLocationUnaries = locationUnaries(startIndex: stopIndex, :);


                laUnary = sun_getUnaryLA(double(tempLocationUnaries), appearanceUnary);
                
                % �ۼ� potentialMatrix
               potentialMatrix.appearance( startIndex: stopIndex, :) = appearanceUnary;
               potentialMatrix.location( startIndex: stopIndex, :) = tempLocationUnaries;
                potentialMatrix.LA( startIndex: stopIndex, :) = laUnary ;
           
                
                
            unaryPotentials( startIndex: stopIndex, : ) = -params.locationWeight2 * log(tempLocationUnaries ) + ...
                -params.appearanceWeight2*log( appearanceUnary ) +...
                -params.laWeight2*log( laUnary );
   
        end

         
    % ����ǰ������
 potentialMatrix.appearance = -log(potentialMatrix.appearance);
 potentialMatrix.location= -log(potentialMatrix.location);
 potentialMatrix.LA = -log(potentialMatrix.LA);
 appearance2 = mapBelief( potentialMatrix.appearance ); location2 = mapBelief( potentialMatrix.location );  LA2 = mapBelief(  potentialMatrix.LA  );
 
  foreground2 = appearance2./maxmax(appearance2) >= 0 |  location2./maxmax(location2) >= 0  |  LA2./maxmax( LA2 ) >= 0;
        % 7  5 7
       %%% ���
%             objectPossibility = loadObject( options, i);
%     if( isempty( objectPossibility ) )
          if( options.vocal ), tic; fprintf( '\t\tComputing objectPossibility...\t' ); end
       objectPossibility = sun_objectPossibility(options,bounds, sun_oldLabels,  potentialMatrix, superpixels, pairPotentials, vNumbers, params, data, i);
            if( options.vocal ), toc; end
%     end
       unaryPotentials = unaryPotentials  - params.objectWeight * log(objectPossibility);

         % ���� unaryPotentials���ֳ�����ǰ������
          unaryPotentials( ~foreground2, 1) = inf;  % ������  -log(5e-100)*30
          unaryPotentials( ~foreground2, 2) = eps;  % -log(1-5e-100)*30
          unaryPotentials(bounds(end-1):bounds(end)-1, : ) = 0;
%       
        [ anyvalue, labels ] = maxflow_mex_optimisedWrapper( pairPotentials, ...
            single( unaryPotentials ) );
        segmentation = superpixelToPixel( labels, superpixels );  %  ��ɾ
        
        if( options.vocal ), toc; end
        
        if( ( i == params.maxIterations ) |...
             all( oldLabels == labels ) ) 

            if( options.vocal ), fprintf( 'videoRapidSegment: Convergence or maximum number of iterations reached\n' ); end

            if( options.visualise )
                if( options.vocal ), tic; fprintf( 'videoRapidSegment: Creating segmentation video...\t' ); end

                videoParams.name = sprintf( 'segmentation%d', data.id );  % �����ṹ����  videoParams
                videoParams.range = data.id;
                mode = 'ShowProcess';

                data.locationProbability = superpixelToPixel( ...
                    locationUnaries( :, 1 ), superpixels );  % ÿ�����ص��϶���һ��λ������ 14 x 1��locationUnaries�ĵ�һ�У����������ڲ�ͼ��Զ��
               
                if min(min(objectPossibility)) < 0
                    objectPossibility = objectPossibility - min(min(objectPossibility));  %% Ϊ����ʾ��ƽ�����ݵ�ԭ��
                end
                data.objectPossibility1 = superpixelToPixel( ...
                    objectPossibility( :, 1 ), superpixels ); 
                data.objectPossibility2 = superpixelToPixel( ...
                    objectPossibility( :, 2 ), superpixels ); 
                
                
                if min(min(potentialMatrix.LA)) < 0
                    potentialMatrix.LA = potentialMatrix.LA - min(min(potentialMatrix.LA));  %% Ϊ����ʾ��ƽ�����ݵ�ԭ��
                end
                data.LA = mapBelief( superpixelToPixel( ...
                    potentialMatrix.LA, superpixels ) ); 
                % α����/��αǰ��+α������  ~ ������Ϊǰ���ı���
                % ÿ�������϶���һ��������ܵ� -log��ǰ������ height x width x ndims
                % �����ڶ�֡��13���õ���fgModel
                app = getUnaryAppearance( single( colours ), fgModel, bgModel );
                data.appearanceProbability = mapBelief( ... 
                    superpixelToPixel( - log( single(  app ) ), superpixels ) );   
               
                % �ۺ� locationProbability �� appearanceProbability�������˳�Ϊǰ���ı���
                % �ڶ���/����һ��+�ڶ��У�
                if min(min(unaryPotentials)) < 0
                    unaryPotentials = unaryPotentials - min(min(unaryPotentials));  %% Ϊ����ʾ��ƽ�����ݵ�ԭ��
                end
                unaryPotentials(isinf(unaryPotentials)) = maxmax(unaryPotentials(~isinf(unaryPotentials)));
                data.unaryPotential = mapBelief( superpixelToPixel( ...
                    unaryPotentials, superpixels ) );   

                data.segmentation = segmentation;

                createSegmentationVideo( options, videoParams, data, mode ,'initial');

                videoParams.name = sprintf( 'segmentation%d-dominantObject', data.id );
                data.segmentation = getLargestSegmentAndNeighbours( ...
                    segmentation );
                createSegmentationVideo( options, videoParams, data, mode ,'dominant');
                clear data

                if( options.vocal ), toc; end
            end
            
            break;
        end
        
        % Check that we did not get a trivial, all-background/foreground
        % segmentation
        if( all( labels ) || all( ~labels ) )
            if( options.vocal ), fprintf( 'videoRapidSegment: Trivial segmentation detected, exiting...\n' ); end
            return;
        end
        
    end

    if( options.vocal ), fprintf( 'videoRapidSegment: Algorithm stopped after %d iterations.\n', i ); end

end
