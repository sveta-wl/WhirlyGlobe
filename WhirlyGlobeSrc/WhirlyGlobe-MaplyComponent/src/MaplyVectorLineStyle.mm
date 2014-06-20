/*
 *  MaplyVectorLineStyle.mm
 *  WhirlyGlobe-MaplyComponent
 *
 *  Created by Steve Gifford on 1/3/14.
 *  Copyright 2011-2014 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import "MaplyVectorLineStyle.h"
#import "MaplyTexture.h"
#import "MaplyTextureBuilder.h"

// Line styles
@implementation MaplyVectorTileStyleLine
{
    NSMutableArray *subStyles;
    BOOL useWideVectors;
}

- (id)initWithStyleEntry:(NSDictionary *)style settings:(MaplyVectorTileStyleSettings *)settings viewC:(MaplyBaseViewController *)viewC
{
    self = [super initWithStyleEntry:style viewC:viewC];
    useWideVectors = YES;
    
    subStyles = [NSMutableArray array];
    NSArray *subStylesArray = style[@"substyles"];
    for (NSDictionary *styleEntry in subStylesArray)
    {
        float strokeWidth = 1.0;
        float alpha = 1.0;
        UIColor *strokeColor = [UIColor blackColor];
      
        // Build up the vector description dictionary
        if (styleEntry[@"stroke-width"])
            strokeWidth = [styleEntry[@"stroke-width"] floatValue];
        if (styleEntry[@"stroke-opacity"])
        {
            alpha = [styleEntry[@"stroke-opacity"] floatValue];
        } else if(styleEntry[@"opacity"]) {
            alpha = [styleEntry[@"opacity"] floatValue];
        }
        if (styleEntry[@"stroke"])
        {
            strokeColor = [MaplyVectorTiles ParseColor:styleEntry[@"stroke"] alpha:alpha];
        }
        
        int drawPriority = 0;
        if (styleEntry[@"drawpriority"])
        {
            drawPriority = (int)[styleEntry[@"drawpriority"] integerValue];
        }
        NSMutableDictionary *desc = [NSMutableDictionary dictionaryWithDictionary:
                                     @{kMaplyVecWidth: @(settings.lineScale * strokeWidth),
                                       kMaplyColor: strokeColor,
                                       kMaplyDrawPriority: @(drawPriority+kMaplyVectorDrawPriorityDefault),
                                       kMaplyEnable: @NO,
                                       kMaplyFade: @0.0,
                                       kMaplyVecCentered: @YES,
                                       kMaplySelectable: @(self.selectable)
                                       }];
        
        if(useWideVectors) {
            int patternLength = 0;
            NSArray *dashComponents;
            if(styleEntry[@"stroke-dasharray"])
            {
                NSArray *componentStrings = [styleEntry[@"stroke-dasharray"] componentsSeparatedByString:@","];
                NSMutableArray *componentNumbers = [NSMutableArray arrayWithCapacity:componentStrings.count];
                for(NSString *s in componentStrings) {
                    int n = [s intValue] * settings.dashPatternScale;
                    patternLength += n;
                    if(n > 0) {
                        [componentNumbers addObject:@(n)];
                    }
                }
                dashComponents = componentNumbers;
            } else  {
                patternLength = 32;
                dashComponents = @[@(patternLength)];
            }
            
            int width = settings.lineScale * strokeWidth;
            // Width needs to be a bit bigger for falloff at edges to work
            if (width < 1)
                width = 1;
            // For odd sizes, we'll expand by 2, even 1
            if (width & 0x1)
                width += 2;
            else
                width += 1;
            MaplyLinearTextureBuilder *lineTexBuilder = [[MaplyLinearTextureBuilder alloc] initWithSize:CGSizeMake(8,patternLength)];
            [lineTexBuilder setPattern:dashComponents];
            lineTexBuilder.opacityFunc = MaplyOpacitySin3;
            UIImage *lineImage = [lineTexBuilder makeImage];
            MaplyTexture *filledLineTex = [viewC addTexture:lineImage
                                                imageFormat:MaplyImageIntRGBA
                                                  wrapFlags:MaplyImageWrapY
                                                       mode:MaplyThreadAny];
            desc[kMaplyVecTexture] = filledLineTex;
            desc[kMaplyWideVecCoordType] = kMaplyWideVecCoordTypeScreen;
            desc[kMaplyWideVecTexRepeatLen] = @(patternLength);
        }
        
        [self resolveVisibility:styleEntry settings:settings desc:desc];
        
        [subStyles addObject:desc];
    }
    
    return self;
}

- (NSArray *)buildObjects:(NSArray *)vecObjs viewC:(MaplyBaseViewController *)viewC;
{
    MaplyComponentObject *baseObj = nil;
    NSMutableArray *compObjs = [NSMutableArray array];
    for (NSDictionary *desc in subStyles)
    {
        MaplyComponentObject *compObj = nil;
        if (!baseObj) {
            if(useWideVectors)
            {
                baseObj = compObj = [viewC addWideVectors:vecObjs desc:desc mode:MaplyThreadCurrent];
            } else
            {
                baseObj = compObj = [viewC addVectors:vecObjs desc:desc mode:MaplyThreadCurrent];
            }
        }
        else
        {
            // Note: Should do current thread here
            if(useWideVectors)
            {
//TODO: I dont think this is right, but it doesnt ever come up with Mapnik Styles, because there is only ever 1 substyle
                compObj = [viewC instanceVectors:baseObj desc:desc mode:MaplyThreadCurrent];
            } else
            {
                compObj = [viewC instanceVectors:baseObj desc:desc mode:MaplyThreadCurrent];
            }
        }
        if (compObj)
            [compObjs addObject:compObj];
    }
    
    return compObjs;
}

@end
