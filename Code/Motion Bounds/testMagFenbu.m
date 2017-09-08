function testMagFenbu(gradient )
% getInOutMaps �е� gradient

magnitude = [];
frames = 6;
for frame = 1 : frames
        gradients(:, :, 1) = gradient.Ux(:, :, frame); gradients(:, :, 2) = gradient.Uy(:, :, frame); 
        gradients(:, :, 3) = gradient.Vx(:, :, frame); gradients(:, :, 4) = gradient.Vy(:, :, frame); 
       magnitude(:, :, frame) = getMagnitude( gradients );
end
mag = sum(magnitude, 3)/frames;
mag2 = magnitude(:, :, 1);

a = reshape(mag,[],1);
figure(1)  ;
hist(a,20)
title('magnitude�ֲ�');

b = a(a~=0);
figure (2)  
hist(b,20)
title('ȥ��0ֵ��magnitude�ֲ�') 

figure (3)
f = a(a>0.15); 
hist(f,20)
title('����0.15��magnitude�ֲ�') 

mu = mean(f)
st = std(f)

% f = sort(f);
% figure (4)
% title('��Ӧ����̬�ֲ�') 
% plot(f, normpdf(f,0.5,1.5))

cmag3 = normcdf(mag2,0.5, 1.5);
figure (5)
imshow(cmag3)
figure (6)
imshow(cmag3>0.6)

cmag4 = 1 - exp(-0.7*mag2);
figure (7)
imshow(cmag4>0.6)
title('ԭʼ����Ч��');
