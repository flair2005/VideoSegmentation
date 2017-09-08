% Function to produce inside-outside maps of a shot given the optical flow
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

function [output, edgePoints] = getInOutMaps( flow )

    frames = length( flow );
    output = cell( frames, 1 );  edgePoints = cell( frames, 1 );

    [ height, width, anyvalue] = size( flow{ 1 } );
    
    % Motion boundaries touching the edges will be cut!
    sideCut = false( height, width );     % ���ܶ��� 1  ������0
    sideCut( 1: 15, : ) = true;
    sideCut( end - 15: end, : ) = true;
    sideCut( :, 1: 15 ) = true;
    sideCut( :, end - 15: end ) = true;
    
         gradient = getFlowGradient( flow );  % ���������������ݶ�
%      results = getFlowGradient( flow );  % ���������������ݶ�
%     gradientU = results(1);
%         gradientV = results(2);
    for( frame = 1: frames )
        % ��֡����������ݶ�
        gradients(:, :, 1) = gradient.Ux(:, :, frame); gradients(:, :, 2) = gradient.Uy(:, :, frame); 
        gradients(:, :, 3) = gradient.Vx(:, :, frame); gradients(:, :, 4) = gradient.Vy(:, :, frame); 
           
%           Uname = fieldnames(gradientU);
%           for i = 1:8
%               temp = eval(sprintf('gradientU.%s', Uname{i}));
%               gradients(:, :, i) = temp(:, :, frame);
%           end
%           
%           Vname = fieldnames(gradientV);
%           for k = 1:8
%               temp = eval(sprintf('gradientV.%s', Vname{k}));
%               gradients(:, :, k+i) = temp(:, :, frame);
%           end
%           
%           
          
          
        [boundaryMap, magnitude] = getProbabilityEdge( gradients, flow{ frame }, 3 );  % �����е�bp����������Ϊ�˶������ĸ��� mode = 3

        % inVotes: ���������У����������ཻΪ�����ε�����; edgePerFrame: �߽� (logical)
        [inVotes, edgePerFrame] = getInPoints( boundaryMap, sideCut, false ); 
        
        if( getFrameQuality( inVotes > 4 ) < 0.2 )   % ��һ�����ܵ�Ŀ�꣬����Ϊ�Ǹ�������
            boundaryMap = calibrateProbabilityEdge(magnitude, flow{ frame }, 0.5, 1.5 );
            inVotes = getInPoints( boundaryMap, sideCut, false );
        end
        
        edgePoints{ frame } = edgePerFrame;
        
        % ��ֵ�˲�
        H = fspecial('gaussian', 5);
        inVotes = filter2(H, inVotes);
        
        output{ frame } = inVotes > 4;
    end    
    
end
