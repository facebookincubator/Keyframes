// Copyright 2004-present Facebook. All Rights Reserved.

#import "KFVectorParsingHelper.h"

#import "KFVector.h"
#import "KFVectorAnimation.h"
#import "KFVectorAnimationGroup.h"
#import "KFVectorAnimationKeyValue.h"
#import "KFVectorAnimationKeyValueBuilder.h"
#import "KFVectorBezierPathsHelper.h"
#import "KFVectorFeature.h"
#import "KFVectorFeatureKeyFrame.h"
#import "KFVectorFeatureKeyFrameBuilder.h"
#import "KFVectorGradientEffect.h"

#pragma mark - Internal structure helpers

static NSArray *_buildTimingCurvesArrayFromDictionary(NSArray *timingCurvesArray)
{
  return KFMapArray(timingCurvesArray, ^id(NSArray *points) {
    NSArray *point1Array = points[0];
    NSArray *point2Array = points[1];

    CGPoint point1 = CGPointMake([point1Array[0] floatValue], [point1Array[1] floatValue]);
    CGPoint point2 = CGPointMake([point2Array[0] floatValue], [point2Array[1] floatValue]);
    return @[[NSValue valueWithCGPoint:point1], [NSValue valueWithCGPoint:point2]];
  });
}

static NSArray *_buildFeatureKeyFrameModelArray(NSArray *keyframesArray, CGSize canvasSize)
{
  return KFMapArray(keyframesArray, ^id(NSDictionary *keyFrameDictionary) {
    return [[KFVectorFeatureKeyFrame alloc]
            initWithType:keyFrameDictionary[@"type"]
            paths:keyFrameDictionary[@"data"]
            startFrame:[keyFrameDictionary[@"start_frame"] unsignedIntegerValue]];
  });
}

static KFVectorAnimation *_buildAnimationModelFromDictionary(NSDictionary *animationDictionary,
                                                                NSUInteger frameRate,
                                                                NSUInteger animationFrameCount,
                                                                CGSize canvasSize)
{
  if (animationDictionary == nil) {
    return nil;
  }
  CGPoint anchor = CGPointZero;
  if (animationDictionary[@"anchor"]) {
    CGFloat anchorX = [animationDictionary[@"anchor"][0] floatValue] / canvasSize.width;
    CGFloat anchorY = [animationDictionary[@"anchor"][1] floatValue] / canvasSize.height;
    anchor = CGPointMake(anchorX, anchorY);
  }

  NSMutableArray *keyValues = KFMapArray(animationDictionary[@"key_values"], ^id(NSDictionary *keyFrameDictionary) {
    return [[KFVectorAnimationKeyValue alloc]
            initWithKeyValue:keyFrameDictionary[@"data"]
            startFrame:[keyFrameDictionary[@"start_frame"] unsignedIntegerValue]];
  }).mutableCopy;
  NSMutableArray *timingCurves = _buildTimingCurvesArrayFromDictionary(animationDictionary[@"timing_curves"]).mutableCopy;

  KFVectorAnimationKeyValue *firstAnimationKeyValue = [keyValues firstObject];
  KFVectorAnimationKeyValue *lastAnimationKeyValue = [keyValues lastObject];

  if (firstAnimationKeyValue.startFrame < 0) {
    [keyValues removeFirstObject];
    [timingCurves removeLastObject];
  }
  if (lastAnimationKeyValue.startFrame > animationFrameCount) {
    [keyValues removeLastObject];
    [timingCurves removeLastObject];
  }

  if (keyValues.count > 0) {
    if (firstAnimationKeyValue.startFrame != 0) {
      // Left extend the first animation key value to start frame 0
      KFVectorAnimationKeyValue *zeroFrameKeyValue =
      [[[KFVectorAnimationKeyValueBuilder
         vectorAnimationKeyValueFromExistingVectorAnimationKeyValue:firstAnimationKeyValue] withStartFrame:0] build];
      [keyValues insertObject:zeroFrameKeyValue atIndex:0];
      [timingCurves insertObject:@[[NSValue valueWithCGPoint:CGPointZero], [NSValue valueWithCGPoint:CGPointMake(1, 1)]] atIndex:0];
    }

    if (lastAnimationKeyValue.startFrame != animationFrameCount) {
      // Right extend the last animation key value to last frame
      KFVectorAnimationKeyValue *endFrameKeyValue =
      [[[KFVectorAnimationKeyValueBuilder
         vectorAnimationKeyValueFromExistingVectorAnimationKeyValue:lastAnimationKeyValue] withStartFrame:animationFrameCount] build];
      [keyValues addObject:endFrameKeyValue];
      [timingCurves addObject:@[[NSValue valueWithCGPoint:CGPointZero], [NSValue valueWithCGPoint:CGPointMake(1, 1)]]];
    }
  }

  return [[KFVectorAnimation alloc]
          initWithProperty:animationDictionary[@"property"]
          anchor:anchor
          frameRate:frameRate
          animationFrameCount:animationFrameCount
          keyValues:keyValues
          timingCurves:timingCurves];
}

static KFVectorGradientEffect *_buildGradientEffectsArrayFromArray(NSDictionary *effectsDictionary,
                                                                      NSUInteger frameRate,
                                                                      NSUInteger animationFrameCount,
                                                                      CGSize canvasSize)
{
  if (!effectsDictionary[@"gradient"]) {
    return nil;
  }

  NSDictionary *gradientEffectDictionary = effectsDictionary[@"gradient"];
  return [[KFVectorGradientEffect alloc]
          initWithGradientTypeString:gradientEffectDictionary[@"gradient_type"]
          colorStart:_buildAnimationModelFromDictionary(gradientEffectDictionary[@"color_start"], frameRate, animationFrameCount, canvasSize)
          colorEnd:_buildAnimationModelFromDictionary(gradientEffectDictionary[@"color_end"], frameRate, animationFrameCount, canvasSize)];
}

static KFVectorFeature *_buildFeatureModelFromDictionary(NSDictionary *featureDictionary,
                                                                             NSUInteger frameRate,
                                                                             NSUInteger animationFrameCount,
                                                                             CGSize canvasSize)
{
  NSMutableArray *keyFrames = _buildFeatureKeyFrameModelArray(featureDictionary[@"key_frames"], canvasSize).mutableCopy;
  NSMutableArray *timingCurves = _buildTimingCurvesArrayFromDictionary(featureDictionary[@"timing_curves"]).mutableCopy;
  NSArray *featureAnimations = KFMapArray(featureDictionary[@"feature_animations"], ^id(NSDictionary *featureAnimationDictionary) {
    return _buildAnimationModelFromDictionary(featureAnimationDictionary, frameRate, animationFrameCount, canvasSize);
  });

  KFVectorFeatureKeyFrame *firstKeyFrame = [keyFrames firstObject];
  KFVectorFeatureKeyFrame *lastKeyFrame = [keyFrames lastObject];

  if (firstKeyFrame.startFrame < 0) {
    [keyFrames removeFirstObject];
    [timingCurves removeLastObject];
  }
  if (lastKeyFrame.startFrame > animationFrameCount) {
    [keyFrames removeLastObject];
    [timingCurves removeLastObject];
  }

  if (keyFrames.count > 0) {
    if (firstKeyFrame.startFrame != 0) {
      // Left extend the first animation key value to start frame 0
      KFVectorFeatureKeyFrame *zeroKeyFrame =
      [[[KFVectorFeatureKeyFrameBuilder
         vectorFeatureKeyFrameFromExistingVectorFeatureKeyFrame:firstKeyFrame] withStartFrame:0] build];
      [keyFrames insertObject:zeroKeyFrame atIndex:0];
      [timingCurves insertObject:@[[NSValue valueWithCGPoint:CGPointZero], [NSValue valueWithCGPoint:CGPointMake(1, 1)]] atIndex:0];
    }

    if (keyFrames.count > 1 &&
        lastKeyFrame.startFrame != animationFrameCount) {
      // Left extend the first animation key value to start frame 0
      KFVectorFeatureKeyFrame *endKeyFrame =
      [[[KFVectorFeatureKeyFrameBuilder
         vectorFeatureKeyFrameFromExistingVectorFeatureKeyFrame:lastKeyFrame] withStartFrame:animationFrameCount] build];
      [keyFrames addObject:endKeyFrame];
      [timingCurves addObject:@[[NSValue valueWithCGPoint:CGPointZero], [NSValue valueWithCGPoint:CGPointMake(1, 1)]]];
    }
  }

  return [[KFVectorFeature alloc]
          initWithName:featureDictionary[@"name"]
          animationGroupId:featureDictionary[@"animation_group"] ? [featureDictionary[@"animation_group"] unsignedIntegerValue] : NSNotFound
          frameRate:frameRate
          animationFrameCount:animationFrameCount
          fillColor:featureDictionary[@"fill_color"] ? KFColorWithHexString(featureDictionary[@"fill_color"]) : nil
          strokeColor:featureDictionary[@"stroke_color"] ? KFColorWithHexString(featureDictionary[@"stroke_color"]) : nil
          strokeWidth:[featureDictionary[@"stroke_width"] floatValue] / MIN(canvasSize.width, canvasSize.height)
          keyFrames:keyFrames
          timingCurves:timingCurves
          featureAnimations:featureAnimations
          gradientEffect:_buildGradientEffectsArrayFromArray(featureDictionary[@"effects"], frameRate, animationFrameCount, canvasSize)];
}

static KFVectorAnimationGroup *_buildAnimationGroupModelFromDictionary(NSDictionary *animationGroupDictionary,
                                                                          NSUInteger frameRate,
                                                                          NSUInteger animationFrameCount,
                                                                          CGSize canvasSize)
{
  return
  [[KFVectorAnimationGroup alloc]
   initWithGroupName:animationGroupDictionary[@"group_name"]
   groupId:[animationGroupDictionary[@"group_id"] integerValue]
   parentGroupId:animationGroupDictionary[@"parent_group"] ? [animationGroupDictionary[@"parent_group"] integerValue] : NSNotFound
   animations:KFMapArray(animationGroupDictionary[@"animations"], ^id(NSDictionary *animationDictionary) {
    return _buildAnimationModelFromDictionary(animationDictionary, frameRate, animationFrameCount, canvasSize);
  })];
}

#pragma mark - Public method

KFVector *KFVectorFromDictionary(NSDictionary *faceDictionary)
{
  CGSize canvasSize = CGSizeMake([faceDictionary[@"canvas_size"][0] floatValue],[faceDictionary[@"canvas_size"][1] floatValue]);

  NSUInteger frameRate = [faceDictionary[@"frame_rate"] unsignedIntegerValue];
  NSUInteger animationFrameCount = [faceDictionary[@"animation_frame_count"] unsignedIntegerValue];
  NSArray *featuresArray = KFMapArray(faceDictionary[@"features"], ^id(NSDictionary *featureDictionary) {
    return _buildFeatureModelFromDictionary(featureDictionary, frameRate, animationFrameCount, canvasSize);
  });

  NSArray *animationGroups = KFMapArray(faceDictionary[@"animation_groups"], ^id(NSDictionary *animationGroupDictionary) {
    return _buildAnimationGroupModelFromDictionary(animationGroupDictionary, frameRate, animationFrameCount, canvasSize);
  });

  return
  [[KFVector alloc]
   initWithCanvasSize:canvasSize
   name:faceDictionary[@"name"]
   key:[faceDictionary[@"key"] integerValue]
   frameRate:frameRate
   animationFrameCount:animationFrameCount
   features:featuresArray
   animationGroups:animationGroups];
}
