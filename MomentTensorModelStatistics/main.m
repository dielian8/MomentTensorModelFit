//
//  main.m
//  MomentTensorModelStatistics
//
//  Created by Jeffrey J. Early on 5/22/14.
//  Copyright (c) 2014 Jeffrey J. Early. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLNumericalModelingKit/GLNumericalModelingKit.h>
#import <GLNumericalModelingKit/GLOperationOptimizer.h>
#import "MomentTensorModels.h"

int main(int argc, const char * argv[])
{

	@autoreleasepool {
		GLFloat floatSpacing = 10;
		GLFloat maxTime = 6*86400;
		GLFloat timeStep = 30*60;
		NSInteger nParticles = 10;
	    GLEquation *equation = [[GLEquation alloc] init];
		GLDimension *floatDim = [[GLDimension alloc] initDimensionWithGrid: kGLEndpointGrid nPoints: nParticles domainMin: 1 length: nParticles];
		GLFunction *xPosition = [GLFunction functionOfRealTypeWithDimensions: @[floatDim] forEquation: equation];
		GLFunction *yPosition = [GLFunction functionOfRealTypeWithDimensions: @[floatDim] forEquation: equation];
		
		// Layout the drifters in a cross pattern, just the real drifters
		NSUInteger iFloat = 0;
		GLFloat length = ((GLFloat) nParticles/2 - 1)*floatSpacing;
		for (NSInteger i=0; i<nParticles/2; i++) {
			xPosition.pointerValue[iFloat] = ((GLFloat) i)*floatSpacing - length/2;
			yPosition.pointerValue[iFloat] = ((GLFloat) i)*0;
			iFloat++;
		}
		for (NSInteger i=0; i<nParticles/2; i++) {
			//if (i==0) continue;
			xPosition.pointerValue[iFloat] = ((GLFloat) i)*0;
			yPosition.pointerValue[iFloat] = ((GLFloat) i)*floatSpacing - length/2;
			iFloat++;
		}
	    
		GLFloat kappa = 1; // m^2/s
        GLFloat norm = sqrt(timeStep*2*kappa);
        norm = sqrt(36./10.)*norm/timeStep; // the integrator multiplies by deltaT, so we account for that here.
        // RK4: dt/3 f(0) + dt/6 f(1) + dt/6 *f(4) + dt/3*f(3)
        // sqrt of ( (1/3)^2 + (1/6)^ + (1/6)^2 + (1/3)^2 )
        
        NSArray *y=@[xPosition, yPosition];
        GLRungeKuttaOperation *integrator = [GLRungeKuttaOperation rungeKutta4AdvanceY: y stepSize: timeStep fFromTY:^(GLScalar *time, NSArray *yNew) {
            GLFunction *xStep = [GLFunction functionWithNormallyDistributedValueWithDimensions: @[floatDim] forEquation: equation];
            GLFunction *yStep = [GLFunction functionWithNormallyDistributedValueWithDimensions: @[floatDim] forEquation: equation];
            xStep = [xStep times: @(norm)];
            yStep = [yStep times: @(norm)];
            
			return @[xStep, yStep];
		}];
		
		GLDimension *tDim = [[GLDimension alloc] initDimensionWithGrid: kGLEndpointGrid nPoints: 1+round(maxTime/timeStep) domainMin: 0 length: maxTime];
		GLFunction *t = [GLFunction functionOfRealTypeFromDimension: tDim withDimensions: @[tDim] forEquation: equation];
		NSArray *newPositions = [integrator integrateAlongDimension: tDim];
				
		GLScalar *meanSquareSeparation0 = [[[xPosition times: xPosition] plus: [yPosition times: yPosition]] mean];
		GLFunction *meanSquareSeparation = [[[newPositions[0] times: newPositions[0]] plus: [newPositions[1] times: newPositions[1]]] mean: 1];
		
		GLFloat a = *(meanSquareSeparation0.pointerValue);
        GLFloat b = meanSquareSeparation.pointerValue[meanSquareSeparation.nDataPoints-1];
        
        GLFloat kappaDeduced = (0.25)*(b-a)/maxTime;
        NSLog(@"kappa: %f, actual kappa: %f", kappa, kappaDeduced);
		
		MomentTensorModels *models = [[MomentTensorModels alloc] initWithXPositions: newPositions[0] yPositions:newPositions[1] time: t];
		NSArray *result = [models bestFitToDiffusivityModel];
		
		GLScalar *minError = result[0];
		GLScalar *minKappa = result[1];
		
		NSLog(@"diffusivity model total error: %f @ (kappa)=(%.4f)", *(minError.pointerValue), *(minKappa.pointerValue));
	}
    return 0;
}

